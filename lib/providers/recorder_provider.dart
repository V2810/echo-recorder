import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_devices_provider.dart';
import '../services/backend_service.dart';
import '../services/metadata_service.dart';
import '../services/wav_writer.dart';
import '../features/recordings/providers/recordings_provider.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

// ─── Foreground Service Bridge ────────────────────────────────────────────────

const _serviceChannel = MethodChannel('com.example.echo_recorder/recorder_service');

Future<void> _startForegroundService() async {
  if (kIsWeb) return;
  try {
    await _serviceChannel.invokeMethod('startForegroundService');
  } catch (e) {
    debugPrint('[RecorderService] startForegroundService error: $e');
  }
}

Future<void> _stopForegroundService() async {
  if (kIsWeb) return;
  try {
    await _serviceChannel.invokeMethod('stopForegroundService');
  } catch (e) {
    debugPrint('[RecorderService] stopForegroundService error: $e');
  }
}

// ─── Recording Name Provider ──────────────────────────────────────────────────

const _counterKey = 'recording_counter';

class CurrentRecordingNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_counterKey) ?? 0;
    return 'Recording ${count + 1}';
  }

  Future<void> updateName(String newName) async {
    state = AsyncData(newName);
  }

  /// Called after a successful save to advance the counter.
  Future<void> advance() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_counterKey) ?? 0) + 1;
    await prefs.setInt(_counterKey, count);
    state = AsyncData('Recording ${count + 1}');
  }
}

final currentRecordingNameProvider =
    AsyncNotifierProvider<CurrentRecordingNameNotifier, String>(
  () => CurrentRecordingNameNotifier(),
);

// ─── Recorder State ───────────────────────────────────────────────────────────

class RecorderState {
  final bool isRecording;
  final bool isPaused;
  final Duration duration;
  final List<double> amplitudes;
  final double dbLevel;
  final double gain;
  final bool isNoiseGateEnabled;
  final double noiseGateThreshold;
  final bool isCompressorEnabled;

  const RecorderState({
    this.isRecording = false,
    this.isPaused = false,
    this.duration = Duration.zero,
    this.amplitudes = const [],
    this.dbLevel = -120.0,
    this.gain = 1.0,
    this.isNoiseGateEnabled = false,
    this.noiseGateThreshold = -50.0,
    this.isCompressorEnabled = true, // On by default
  });

  RecorderState copyWith({
    bool? isRecording,
    bool? isPaused,
    Duration? duration,
    List<double>? amplitudes,
    double? dbLevel,
    double? gain,
    bool? isNoiseGateEnabled,
    double? noiseGateThreshold,
    bool? isCompressorEnabled,
  }) {
    return RecorderState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      duration: duration ?? this.duration,
      amplitudes: amplitudes ?? this.amplitudes,
      dbLevel: dbLevel ?? this.dbLevel,
      gain: gain ?? this.gain,
      isNoiseGateEnabled: isNoiseGateEnabled ?? this.isNoiseGateEnabled,
      noiseGateThreshold: noiseGateThreshold ?? this.noiseGateThreshold,
      isCompressorEnabled: isCompressorEnabled ?? this.isCompressorEnabled,
    );
  }
}

// ─── Recorder Notifier ────────────────────────────────────────────────────────

class RecorderNotifier extends Notifier<RecorderState> {
  late final AudioRecorder _audioRecorder;
  StreamSubscription<Uint8List>? _audioStreamSub;
  WavWriter? _wavWriter;
  Timer? _timer;
  int _seconds = 0;
  String? _currentFilePath;
  bool _isStopping = false; // double-stop guard

  // Noise gate hold: write real audio for this many chunks after last loud
  // chunk, preventing word endings from being clipped.
  static const int _holdChunks = 10;
  int _holdCounter = 0;

  // Compressor state
  double _compressorEnvelope = 0.0;

  @override
  RecorderState build() {
    _audioRecorder = AudioRecorder();
    ref.onDispose(() {
      _timer?.cancel();
      _audioStreamSub?.cancel();
      _audioRecorder.dispose();
    });
    Future.microtask(() => initAudioStream());
    return const RecorderState();
  }

  ({double linear, double db}) _calculateAmplitude(Uint8List pcmData) {
    if (pcmData.isEmpty) return (linear: 0.0, db: -120.0);
    final data = ByteData.view(pcmData.buffer, pcmData.offsetInBytes, pcmData.lengthInBytes);
    double sum = 0.0;
    int count = 0;
    for (int i = 0; i < data.lengthInBytes - 1; i += 2) {
      final sample = data.getInt16(i, Endian.little);
      sum += sample * sample;
      count++;
    }
    if (count == 0) return (linear: 0.0, db: -120.0);
    final rms = math.sqrt(sum / count);
    final linear = rms / 32768.0;
    final db = rms == 0 ? -120.0 : 20 * (math.log(linear) / math.ln10);
    return (linear: linear, db: db);
  }

  void _applyCompressor(Uint8List pcmData) {
    if (pcmData.isEmpty) return;
    final data = ByteData.view(
        pcmData.buffer, pcmData.offsetInBytes, pcmData.lengthInBytes);

    // Compressor settings
    const double thresholdDb = -12.0; // Start compressing at -12 dB
    const double ratio = 4.0; // 4:1 compression ratio
    const double attackSec = 0.005; // 5ms attack (fast)
    const double releaseSec = 0.100; // 100ms release
    const double makeUpGainDb = 3.0; // Add 3dB gain after compression to make it clear
    const double sampleRate = 44100.0;

    final attackCoef = math.exp(-1.0 / (attackSec * sampleRate));
    final releaseCoef = math.exp(-1.0 / (releaseSec * sampleRate));
    final thresholdLinear = math.pow(10.0, thresholdDb / 20.0);
    final makeUpLinear = math.pow(10.0, makeUpGainDb / 20.0);

    for (int i = 0; i < data.lengthInBytes - 1; i += 2) {
      final sample = data.getInt16(i, Endian.little);
      final double sampleLinear = sample.abs() / 32768.0;

      // Envelope detection
      if (sampleLinear > _compressorEnvelope) {
        _compressorEnvelope =
            attackCoef * _compressorEnvelope + (1.0 - attackCoef) * sampleLinear;
      } else {
        _compressorEnvelope =
            releaseCoef * _compressorEnvelope + (1.0 - releaseCoef) * sampleLinear;
      }

      double gainReduction = 1.0;
      if (_compressorEnvelope > thresholdLinear && _compressorEnvelope > 0) {
        final envDb = 20.0 * math.log(_compressorEnvelope) / math.ln10;
        final overDb = envDb - thresholdDb;
        final reducedOverDb = overDb / ratio;
        final targetDb = thresholdDb + reducedOverDb;
        final targetLinear = math.pow(10.0, targetDb / 20.0);
        gainReduction = targetLinear / _compressorEnvelope;
      }

      // Apply compression and makeup gain
      double processedSample = sample * gainReduction * makeUpLinear;

      // Hard clipping (Limiter) to strictly prevent distortion
      if (processedSample > 32767) processedSample = 32767;
      if (processedSample < -32768) processedSample = -32768;

      data.setInt16(i, processedSample.toInt(), Endian.little);
    }
  }

  Uint8List _zeroPad(Uint8List original) => Uint8List(original.length);

  Future<void> initAudioStream() async {
    if (_audioStreamSub != null) return;

    if (kIsWeb) {
      if (!await _audioRecorder.hasPermission()) return;
    } else {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
    }

    final selectedDevice = ref.read(selectedAudioDeviceProvider);
    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,
      device: selectedDevice,
      noiseSuppress: true,
      echoCancel: true,
    );

    final stream = await _audioRecorder.startStream(config);
    _audioStreamSub = stream.listen((data) {
      if (state.isCompressorEnabled) {
        _applyCompressor(data);
      }

      final amps = _calculateAmplitude(data);
      final dbLevel = amps.db;

      // Scale linear amplitude for visually pleasing waveforms
      double visualAmp = (math.pow(amps.linear, 0.7) * 2.0 * state.gain).toDouble();
      visualAmp = visualAmp.clamp(0.0, 1.0);

      final newAmps = List<double>.from(state.amplitudes);
      newAmps.add(visualAmp);
      if (newAmps.length > 120) newAmps.removeAt(0);

      if (state.isRecording && !state.isPaused) {
        final bool isBelowThreshold =
            state.isNoiseGateEnabled && dbLevel < state.noiseGateThreshold;

        if (!isBelowThreshold) {
          _holdCounter = _holdChunks;
          _wavWriter?.write(data);
        } else if (_holdCounter > 0) {
          _holdCounter--;
          _wavWriter?.write(data);
        } else {
          _wavWriter?.write(_zeroPad(data));
        }
      }

      state = state.copyWith(amplitudes: newAmps, dbLevel: dbLevel);
    });
  }

  Future<void> restartStream() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    _holdCounter = 0;
    await _audioRecorder.stop();
    await initAudioStream();
  }

  Future<void> startRecording() async {
    if (state.isRecording) return; // already recording
    if (_audioStreamSub == null) await initAudioStream();

    String? path;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      // Use the async value; fall back to a timestamp if not yet loaded
      final nameAsync = ref.read(currentRecordingNameProvider);
      final filename = nameAsync.value ?? 
          'Recording_${DateTime.now().millisecondsSinceEpoch}';
      path = '${dir.path}/$filename.wav';
    }

    _currentFilePath = path;
    _holdCounter = 0;
    _isStopping = false;

    if (path != null) {
      _wavWriter = WavWriter(path, sampleRate: 44100, channels: 1);
      await _wavWriter!.open();
    }

    _seconds = 0;
    _startTimer();
    await _startForegroundService();

    state = state.copyWith(isRecording: true, isPaused: false);
  }

  Future<void> pauseRecording() async {
    if (!state.isRecording || state.isPaused) return;
    _timer?.cancel();
    state = state.copyWith(isPaused: true);
  }

  Future<void> resumeRecording() async {
    if (!state.isRecording || !state.isPaused) return;
    _startTimer();
    state = state.copyWith(isPaused: false);
  }

  Future<void> stopRecording() async {
    // Double-stop guard
    if (!state.isRecording || _isStopping) return;
    _isStopping = true;

    _timer?.cancel();
    await _wavWriter?.close();
    _wavWriter = null;

    final path = _currentFilePath;
    final finalDuration = state.duration;

    await _stopForegroundService();

    state = state.copyWith(
      isRecording: false,
      isPaused: false,
      duration: Duration.zero,
    );

    if (path != null) {
      // Save metadata with the clean display title
      final nameAsync = ref.read(currentRecordingNameProvider);
      final displayTitle = nameAsync.value ??
          Uri.file(path).pathSegments.last;

      await MetadataService().saveMetadata(
        path,
        RecordingMetadata(title: displayTitle, duration: finalDuration),
      );

      // Advance the name immediately so the next recording gets a new name
      await ref.read(currentRecordingNameProvider.notifier).advance();
      ref.read(recordingsProvider.notifier).refresh();

      // Run upload in the background so it doesn't block UI state
      BackendService.uploadAudio(path).then((success) {
        if (success) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Upload successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }

    _isStopping = false;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      if (!state.isPaused) {
        _seconds++;
        state = state.copyWith(duration: Duration(seconds: _seconds));
        if (_seconds % 5 == 0) await _wavWriter?.checkpoint();
      }
    });
  }

  void setGain(double gain) => state = state.copyWith(gain: gain);

  void toggleNoiseGate(bool enabled) {
    _holdCounter = 0;
    state = state.copyWith(isNoiseGateEnabled: enabled);
  }

  void setNoiseGateThreshold(double threshold) =>
      state = state.copyWith(noiseGateThreshold: threshold);

  void toggleCompressor(bool enabled) =>
      state = state.copyWith(isCompressorEnabled: enabled);
}

final recorderProvider =
    NotifierProvider<RecorderNotifier, RecorderState>(() => RecorderNotifier());

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../widgets/glowing_record_button.dart';
import '../../../widgets/live_waveform.dart';
import '../../../providers/audio_devices_provider.dart';
import '../../../providers/recorder_provider.dart';
import '../../recordings/presentation/recordings_screen.dart';
import '../../settings/presentation/settings_screen.dart';

// ─── Recorder Screen ──────────────────────────────────────────────────────────

class RecorderScreen extends ConsumerWidget {
  const RecorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorderState = ref.watch(recorderProvider);
    final audioDevicesAsync = ref.watch(audioDevicesProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar ──
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.list_bullet,
                        color: Colors.white70),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecordingsScreen()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.settings,
                        color: Colors.white70),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Microphone selector ──
              _MicrophoneSelector(audioDevicesAsync: audioDevicesAsync),

              const Spacer(),

              // ── Live waveform ──
              RepaintBoundary(
                child: LiveWaveform(
                  amplitudes: recorderState.amplitudes.isEmpty
                      ? List.generate(60, (_) => 0.0)
                      : recorderState.amplitudes,
                  isRecording:
                      recorderState.isRecording && !recorderState.isPaused,
                ),
              ),

              const Spacer(),

              // ── Timer ──
              Center(
                child: Text(
                  _formatDuration(recorderState.duration),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                  ),
                ),
              ),

              // ── Recording name row ──
              _RecordingNameRow(isRecording: recorderState.isRecording),

              const SizedBox(height: 16),

              // ── VU meter ──
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: _GradientVolumeMeter(
                    value: ((recorderState.dbLevel + 60) / 60).clamp(0.0, 1.0),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Audio Effects (Noise Gate + Compressor) ──
              _AudioEffectsControl(recorderState: recorderState),

              const SizedBox(height: 16),

              // ── Transport controls ──
              _TransportControls(
                recorderState: recorderState,
                audioDevicesAsync: audioDevicesAsync,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final mm = two(duration.inMinutes.remainder(60));
    final ss = two(duration.inSeconds.remainder(60));
    final ms =
        (duration.inMilliseconds.remainder(1000) / 100).floor().toString();
    return '$mm:$ss.$ms';
  }
}

// ─── Microphone Selector ──────────────────────────────────────────────────────

class _MicrophoneSelector extends ConsumerWidget {
  final AsyncValue<List<InputDevice>> audioDevicesAsync;
  const _MicrophoneSelector({required this.audioDevicesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: audioDevicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return const Text(
              'No Microphones Found',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            );
          }
          final selected = ref.watch(selectedAudioDeviceProvider);
          return DropdownButtonHideUnderline(
            child: DropdownButton<InputDevice>(
              value: selected,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white54),
              isExpanded: true,
              dropdownColor: const Color(0xFF23252A),
              selectedItemBuilder: (context) {
                return devices.map<Widget>((item) {
                  return Row(
                    children: [
                      const Text(
                        'Microphone',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          item.label.isNotEmpty ? item.label : 'Default',
                          style:
                              const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              items: devices.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text(
                    device.label.isNotEmpty ? device.label : 'Default',
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (device) {
                ref
                    .read(selectedAudioDeviceProvider.notifier)
                    .select(device);
                ref.read(recorderProvider.notifier).restartStream();
              },
            ),
          );
        },
        loading: () => const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) =>
            const Text('Error loading microphones',
                style: TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}

// ─── Recording Name Row ───────────────────────────────────────────────────────

class _RecordingNameRow extends ConsumerWidget {
  final bool isRecording;
  const _RecordingNameRow({required this.isRecording});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(currentRecordingNameProvider);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          nameAsync.when(
            data: (name) => Text(
              name,
              style: const TextStyle(
                  color: Colors.white54, fontStyle: FontStyle.italic),
            ),
            loading: () => const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white38),
            ),
            error: (_, __) => const Text('Recording',
                style: TextStyle(color: Colors.white54)),
          ),
          if (!isRecording) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final current =
                    ref.read(currentRecordingNameProvider).value ?? '';
                final controller =
                    TextEditingController(text: current);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF23252A),
                    title: const Text('Set Recording Name',
                        style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Meeting Notes',
                        hintStyle: TextStyle(color: Colors.white38),
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFFF95B5B)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.white24),
                        ),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            ref
                                .read(currentRecordingNameProvider
                                    .notifier)
                                .updateName(name);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Save',
                            style:
                                TextStyle(color: Color(0xFFF95B5B))),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.edit,
                  color: Colors.white54, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Audio Effects Control ────────────────────────────────────────────────────

class _AudioEffectsControl extends ConsumerWidget {
  final RecorderState recorderState;
  const _AudioEffectsControl({required this.recorderState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strengthPct =
        ((recorderState.noiseGateThreshold + 80) / 80 * 100)
            .round()
            .clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centred label + switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Noise Gate
              Row(
                children: [
                  const Text(
                    'Noise Gate',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: recorderState.isNoiseGateEnabled,
                      activeThumbColor: const Color(0xFFF95B5B),
                      activeTrackColor:
                          const Color(0xFFF95B5B).withValues(alpha: 0.4),
                      onChanged: (val) =>
                          ref.read(recorderProvider.notifier).toggleNoiseGate(val),
                    ),
                  ),
                ],
              ),
              // Compressor
              Row(
                children: [
                  const Text(
                    'Auto Level',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: recorderState.isCompressorEnabled,
                      activeThumbColor: const Color(0xFFF95B5B),
                      activeTrackColor:
                          const Color(0xFFF95B5B).withValues(alpha: 0.4),
                      onChanged: (val) =>
                          ref.read(recorderProvider.notifier).toggleCompressor(val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (recorderState.isNoiseGateEnabled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Less',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11)),
                Text(
                  'Gate Strength: $strengthPct%',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const Text('More',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            Slider(
              value: (recorderState.noiseGateThreshold + 80).clamp(0.0, 80.0),
              min: 0.0,
              max: 80.0,
              divisions: 80,
              activeColor: const Color(0xFFF95B5B),
              inactiveColor: Colors.white12,
              onChanged: (val) => ref
                  .read(recorderProvider.notifier)
                  .setNoiseGateThreshold(val - 80.0),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Transport Controls (Record + Pause/Resume) ───────────────────────────────

class _TransportControls extends ConsumerWidget {
  final RecorderState recorderState;
  final AsyncValue<List<InputDevice>> audioDevicesAsync;

  const _TransportControls({
    required this.recorderState,
    required this.audioDevicesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasDevices =
        audioDevicesAsync.value?.isNotEmpty ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Pause / Resume (only visible while recording) ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: recorderState.isRecording
              ? Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: _ControlButton(
                    icon: recorderState.isPaused
                        ? CupertinoIcons.play_circle_fill
                        : CupertinoIcons.pause_circle_fill,
                    label: recorderState.isPaused ? 'Resume' : 'Pause',
                    onTap: () {
                      if (recorderState.isPaused) {
                        ref
                            .read(recorderProvider.notifier)
                            .resumeRecording();
                      } else {
                        ref
                            .read(recorderProvider.notifier)
                            .pauseRecording();
                      }
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Record / Stop ──
        GlowingRecordButton(
          isRecording: recorderState.isRecording && !recorderState.isPaused,
          onPressed: !hasDevices
              ? null
              : () {
                  if (recorderState.isRecording) {
                    ref.read(recorderProvider.notifier).stopRecording();
                  } else {
                    ref.read(recorderProvider.notifier).startRecording();
                  }
                },
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFF95B5B), size: 44),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Segmented VU Volume Meter ────────────────────────────────────────────────

class _GradientVolumeMeter extends StatelessWidget {
  final double value;
  const _GradientVolumeMeter({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: CustomPaint(
        painter: _VuMeterPainter(value.clamp(0.0, 1.0)),
        size: const Size(double.infinity, 16),
      ),
    );
  }
}

class _VuMeterPainter extends CustomPainter {
  final double value;
  _VuMeterPainter(this.value);

  static const int _totalSegments = 40;
  static const double _barFraction = 0.75;
  static const int _yellowStart = 29;
  static const int _orangeStart = 34;
  static const int _redStart = 37;

  static const Color _litGreen = Color(0xFF4CAF50);
  static const Color _litYellow = Color(0xFFFFD600);
  static const Color _litOrange = Color(0xFFFF6D00);
  static const Color _litRed = Color(0xFFF44336);
  static const Color _dimGreen = Color(0xFF1B3A1B);
  static const Color _dimYellow = Color(0xFF3A2E00);
  static const Color _dimOrange = Color(0xFF3A1A00);
  static const Color _dimRed = Color(0xFF3A0A0A);

  Color _litColor(int i) {
    if (i >= _redStart) return _litRed;
    if (i >= _orangeStart) return _litOrange;
    if (i >= _yellowStart) return _litYellow;
    return _litGreen;
  }

  Color _dimColor(int i) {
    if (i >= _redStart) return _dimRed;
    if (i >= _orangeStart) return _dimOrange;
    if (i >= _yellowStart) return _dimYellow;
    return _dimGreen;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int litCount = (value * _totalSegments).round();
    final double cellWidth = size.width / _totalSegments;
    final double barWidth = cellWidth * _barFraction;
    final double gapWidth = cellWidth - barWidth;
    const double cornerR = 2.0;
    final paint = Paint();

    for (int i = 0; i < _totalSegments; i++) {
      final bool lit = i < litCount;
      paint.color = lit ? _litColor(i) : _dimColor(i);
      final double left = i * cellWidth + gapWidth / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, barWidth, size.height),
          const Radius.circular(cornerR),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VuMeterPainter old) => old.value != value;
}

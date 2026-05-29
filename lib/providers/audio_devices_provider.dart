import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

final audioDevicesProvider = FutureProvider<List<InputDevice>>((ref) async {
  final record = AudioRecorder();
  try {
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return [];
    } else {
      if (!await record.hasPermission()) return [];
    }
    return await record.listInputDevices();
  } catch (e) {
    debugPrint('[audioDevicesProvider] Failed to list input devices: $e');
    return [];
  } finally {
    // Always dispose, even if an exception is thrown
    await record.dispose();
  }
});

class SelectedAudioDeviceNotifier extends Notifier<InputDevice?> {
  @override
  InputDevice? build() => null;

  void select(InputDevice? device) {
    state = device;
  }
}

final selectedAudioDeviceProvider =
    NotifierProvider<SelectedAudioDeviceNotifier, InputDevice?>(
  () => SelectedAudioDeviceNotifier(),
);

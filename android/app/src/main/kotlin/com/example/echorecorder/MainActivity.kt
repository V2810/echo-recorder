package com.example.echorecorder

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.echorecorder/audio"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getAudioInputDevices" -> {
                    result.success(getAudioInputDevices())
                }
                "setPreferredDevice" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    result.success(setPreferredDevice(deviceId))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getAudioInputDevices(): List<Map<String, Any>> {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val devices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
        } else {
            arrayOf<AudioDeviceInfo>()
        }
        return devices.filter { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_USB_DEVICE ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                it.type == AudioDeviceInfo.TYPE_USB_HEADSET }
            .map {
                mapOf(
                    "id" to it.id,
                    "productName" to it.productName.toString(),
                    "type" to it.type
                )
            }
    }

    private fun setPreferredDevice(deviceId: Int?): Boolean {
        // Stub: Implement routing logic with AudioRecord and setPreferredDevice
        return deviceId != null
    }
}

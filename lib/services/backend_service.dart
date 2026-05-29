import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendService {
  /// Set this to your actual backend URL.
  /// For local development: 'http://10.0.2.2:8000/upload-audio' (Android emulator)
  /// For production: your deployed API endpoint.
  static const String _backendUrl = 'http://10.0.2.2:8000/upload-audio';

  static const Duration _uploadTimeout = Duration(seconds: 60);

  static Future<bool> uploadAudio(String pathOrUrl) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      if (kIsWeb) {
        final response = await http
            .get(Uri.parse(pathOrUrl))
            .timeout(_uploadTimeout);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            response.bodyBytes,
            filename: 'recording.wav',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', pathOrUrl),
        );
      }

      final streamedResponse =
          await request.send().timeout(_uploadTimeout);

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        debugPrint('[BackendService] Upload successful');
        return true;
      } else {
        debugPrint(
          '[BackendService] Upload failed — HTTP ${streamedResponse.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[BackendService] Upload error: $e');
      return false;
    }
  }
}

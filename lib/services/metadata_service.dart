import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingMetadata {
  final String title;
  final Duration duration;
  final bool isFavorite;

  RecordingMetadata({
    required this.title,
    required this.duration,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'durationMs': duration.inMilliseconds,
    'isFavorite': isFavorite,
  };

  factory RecordingMetadata.fromJson(Map<String, dynamic> json) => RecordingMetadata(
    title: json['title'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}

class MetadataService {
  static const String _prefsKey = 'recordings_metadata';

  // Singleton
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Map<String, RecordingMetadata> getAllMetadata() {
    final str = _prefs?.getString(_prefsKey);
    if (str == null || str.isEmpty) return {};

    final Map<String, dynamic> decoded = jsonDecode(str);
    return decoded.map((key, value) => MapEntry(key, RecordingMetadata.fromJson(value)));
  }

  Future<void> saveMetadata(String path, RecordingMetadata metadata) async {
    final map = getAllMetadata();
    map[path] = metadata;
    await _prefs?.setString(_prefsKey, jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> deleteMetadata(String path) async {
    final map = getAllMetadata();
    if (map.containsKey(path)) {
      map.remove(path);
      await _prefs?.setString(_prefsKey, jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recording_model.dart';
import '../../../services/metadata_service.dart';

class RecordingsNotifier extends AsyncNotifier<List<Recording>> {
  @override
  Future<List<Recording>> build() async {
    return _fetchRecordings();
  }

  Future<List<Recording>> _fetchRecordings() async {
    if (kIsWeb) return [];

    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav')).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final metaMap = MetadataService().getAllMetadata();

      return files.map((file) {
        final stat = file.statSync();
        final filename = file.uri.pathSegments.last;
        final meta = metaMap[file.path];

        return Recording(
          id: file.path,
          title: meta?.title ?? filename,
          date: stat.modified,
          duration: meta?.duration ?? const Duration(),
          isFavorite: meta?.isFavorite ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching recordings: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRecordings());
  }

  Future<void> toggleFavorite(Recording recording) async {
    final meta = RecordingMetadata(
      title: recording.title,
      duration: recording.duration,
      isFavorite: !recording.isFavorite,
    );
    await MetadataService().saveMetadata(recording.id, meta);
    await refresh();
  }

  Future<void> renameRecording(Recording recording, String newTitle) async {
    final meta = RecordingMetadata(
      title: newTitle,
      duration: recording.duration,
      isFavorite: recording.isFavorite,
    );
    await MetadataService().saveMetadata(recording.id, meta);
    await refresh();
  }

  Future<void> deleteRecording(Recording recording) async {
    final file = File(recording.id);
    if (file.existsSync()) {
      file.deleteSync();
    }
    await MetadataService().deleteMetadata(recording.id);
    await refresh();
  }
}

final recordingsProvider = AsyncNotifierProvider<RecordingsNotifier, List<Recording>>(() {
  return RecordingsNotifier();
});

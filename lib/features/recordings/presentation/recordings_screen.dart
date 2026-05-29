import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recording_model.dart';
import '../providers/recordings_provider.dart';
import 'recording_item_widget.dart';

// ─── Sort Mode ────────────────────────────────────────────────────────────────

enum _SortMode { newest, oldest, name, duration, favorites }

extension _SortModeLabel on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.newest:    return 'Newest';
      case _SortMode.oldest:    return 'Oldest';
      case _SortMode.name:      return 'Name';
      case _SortMode.duration:  return 'Duration';
      case _SortMode.favorites: return 'Favorites';
    }
  }
}

// ─── Recordings Screen ────────────────────────────────────────────────────────

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.newest;
  bool _showSearchBar = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Recording> _filtered(List<Recording> all) {
    var list = all.toList();

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.newest:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortMode.oldest:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortMode.name:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortMode.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case _SortMode.favorites:
        list.sort((a, b) {
          if (a.isFavorite == b.isFavorite) {
            return b.date.compareTo(a.date);
          }
          return a.isFavorite ? -1 : 1;
        });
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Search toggle
                  IconButton(
                    icon: Icon(
                      _showSearchBar
                          ? CupertinoIcons.search_circle_fill
                          : CupertinoIcons.search,
                      color: _showSearchBar
                          ? const Color(0xFFF95B5B)
                          : Colors.white70,
                    ),
                    onPressed: () => setState(() {
                      _showSearchBar = !_showSearchBar;
                      if (!_showSearchBar) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    }),
                  ),
                  // Sort
                  PopupMenuButton<_SortMode>(
                    icon: const Icon(CupertinoIcons.sort_down,
                        color: Colors.white70),
                    color: const Color(0xFF23252A),
                    onSelected: (mode) =>
                        setState(() => _sortMode = mode),
                    itemBuilder: (_) => _SortMode.values
                        .map(
                          (m) => PopupMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                if (m == _sortMode)
                                  const Icon(Icons.check,
                                      size: 16,
                                      color: Color(0xFFF95B5B))
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(m.label,
                                    style: const TextStyle(
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            // ── Search bar (animated) ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _showSearchBar
                  ? Padding(
                      key: const ValueKey('searchbar'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search recordings…',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.white38),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                  child: const Icon(Icons.close,
                                      color: Colors.white38),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF23252A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Recordings',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Sort chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF23252A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _sortMode.label,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // ── List ──
            Expanded(
              child: recordingsAsync.when(
                data: (recordings) {
                  final filtered = _filtered(recordings);

                  if (filtered.isEmpty) {
                    return _EmptyState(
                      isFiltered: _searchQuery.isNotEmpty ||
                          _sortMode == _SortMode.favorites,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16)
                        .copyWith(bottom: 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        RecordingItemWidget(recording: filtered[i]),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFF95B5B)),
                ),
                error: (err, _) => Center(
                  child: Text('Error: $err',
                      style:
                          const TextStyle(color: Colors.redAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF95B5B),
        shape: const CircleBorder(),
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.fiber_manual_record,
            color: Colors.black54),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered
                  ? CupertinoIcons.search
                  : CupertinoIcons.mic_slash,
              size: 72,
              color: Colors.white12,
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered
                  ? 'No recordings match your search'
                  : 'No recordings yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered
                  ? 'Try a different search term or sort.'
                  : 'Tap the record button to\ncreate your first recording.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white30, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

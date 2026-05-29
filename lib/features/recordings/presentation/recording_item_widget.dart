import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/recording_model.dart';
import '../providers/recordings_provider.dart';

class RecordingItemWidget extends ConsumerStatefulWidget {
  final Recording recording;
  const RecordingItemWidget({super.key, required this.recording});

  @override
  ConsumerState<RecordingItemWidget> createState() => _RecordingItemWidgetState();
}

class _RecordingItemWidgetState extends ConsumerState<RecordingItemWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isExpanded = false; // scrubber visible even before playback starts
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setSourceDeviceFile(widget.recording.id);
    
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          // Keep expanded so user can replay from any position
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF23252A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.share, color: Colors.blueAccent),
              title: const Text('Share', style: TextStyle(color: Colors.blueAccent)),
              onTap: () async {
                Navigator.pop(context);
                await Share.shareXFiles([XFile(widget.recording.id)], text: widget.recording.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.delete, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                ref.read(recordingsProvider.notifier).deleteRecording(widget.recording);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.recording.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF23252A),
        title: const Text('Rename Recording', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFF95B5B))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref.read(recordingsProvider.notifier).renameRecording(widget.recording, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFF95B5B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = _isExpanded || _isPlaying || _position > Duration.zero;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF23252A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Play Button
              IconButton(
                icon: Icon(_isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill),
                color: const Color(0xFFF95B5B),
                iconSize: 36,
                onPressed: () {
                  if (_isPlaying) {
                    _player.pause();
                  } else {
                    _player.resume();
                  }
                },
              ),
              const SizedBox(width: 8),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recording.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat("MMM d, yyyy 'at' h:mm a").format(widget.recording.date),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showOptions(context),
                        child: const Icon(CupertinoIcons.ellipsis, color: Colors.white54),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.recording.durationFormatted,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.read(recordingsProvider.notifier).toggleFavorite(widget.recording),
                    child: Icon(
                      widget.recording.isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: widget.recording.isFavorite ? const Color(0xFFF95B5B) : Colors.white30,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Slider for playback
          if (isExpanded) ...[
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 2,
              ),
              child: Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                activeColor: const Color(0xFFF95B5B),
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  _player.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ]
        ],
      ),       // Column
      ),       // Container
    );         // GestureDetector
  }
}

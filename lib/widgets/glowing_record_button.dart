import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium glowing record button with:
/// - Pulsing red outer ring while recording
/// - Stop icon (square) while recording, record icon (circle) when idle
/// - Haptic feedback on press
class GlowingRecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onPressed;

  const GlowingRecordButton({
    super.key,
    required this.isRecording,
    this.onPressed,
  });

  @override
  State<GlowingRecordButton> createState() => _GlowingRecordButtonState();
}

class _GlowingRecordButtonState extends State<GlowingRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(GlowingRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;
    const Color activeColor = Color(0xFFF95B5B);

    return GestureDetector(
      onTap: () {
        if (widget.onPressed == null) return;
        // Tactile feedback — heavy for start, medium for stop
        if (!widget.isRecording) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
        widget.onPressed!();
      },
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing outer ring (only visible while recording)
                if (widget.isRecording)
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withOpacity(
                          (1.5 - _pulseAnim.value).clamp(0.0, 0.3),
                        ),
                      ),
                    ),
                  ),
                // Core button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? activeColor : Colors.white24,
                    boxShadow: widget.isRecording
                        ? [
                            BoxShadow(
                              color: activeColor.withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    widget.isRecording
                        ? Icons.stop_rounded
                        : Icons.fiber_manual_record,
                    color: isEnabled ? Colors.white : Colors.white30,
                    size: 40,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

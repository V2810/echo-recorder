import 'package:flutter/material.dart';

class LiveWaveform extends StatelessWidget {
  final List<double> amplitudes;
  final bool isRecording;

  const LiveWaveform({
    super.key,
    required this.amplitudes,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1F22),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: CustomPaint(
        painter: _WaveformPainter(
          isRecording ? amplitudes : const [],
          isRecording: isRecording,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final bool isRecording;

  _WaveformPainter(this.amplitudes, {required this.isRecording});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    final width = size.width;

    // Not recording — draw a subtle flat idle line
    if (!isRecording || amplitudes.isEmpty || amplitudes.every((a) => a == 0)) {
      canvas.drawLine(
        Offset(0, midY),
        Offset(width, midY),
        paint..color = Colors.white24,
      );
      return;
    }

    const barWidth = 4.0;
    const spacing = 3.0;
    const step = barWidth + spacing;
    final totalBars = (width / step).floor();

    final displayAmps = amplitudes.length > totalBars
        ? amplitudes.sublist(amplitudes.length - totalBars)
        : amplitudes;

    final startX = width - (displayAmps.length * step);

    for (int i = 0; i < displayAmps.length; i++) {
      final x = startX + (i * step);
      final barHeight = (displayAmps[i] * (midY - 20)).clamp(2.0, midY - 10.0);

      // Colour bars based on amplitude: quiet = white, loud = red tint
      final amp = displayAmps[i].clamp(0.0, 1.0);
      final color = Color.lerp(Colors.white54, const Color(0xFFF95B5B), amp)!;

      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes ||
      oldDelegate.isRecording != isRecording;
}

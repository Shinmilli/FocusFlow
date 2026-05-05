import 'package:flutter/material.dart';

import '../../../../app/theme/app_chrome.dart';

class TimeFlowRing extends StatelessWidget {
  const TimeFlowRing({
    super.key,
    required this.progress,
    required this.centerLabel,
    this.centerColor,
  });

  final double progress;
  final String centerLabel;
  final Color? centerColor;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final labelStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: centerColor ?? const Color(0xFF2C3140),
          fontWeight: FontWeight.w800,
        );
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _RingPainter(p, AppChrome.heroAccentBlue),
        child: Center(
          child: Text(centerLabel, style: labelStyle),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final bg = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, bg);
    final sweep = 2 * 3.141592653589793 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

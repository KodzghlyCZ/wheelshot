import 'package:flutter/material.dart';

import '../vision/dot_ocr.dart';

/// Guide oval for the DOT date stamp. Caption shows the settled WWYY.
class DotAimOverlayPainter extends CustomPainter {
  const DotAimOverlayPainter(this.date);

  final DotDate? date;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = dotAimRect(size);
    final guide = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(rect, guide);

    final label = date == null ? '4 digits' : date!.label;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.bottom + 10),
    );
  }

  @override
  bool shouldRepaint(covariant DotAimOverlayPainter oldDelegate) =>
      oldDelegate.date != date;
}

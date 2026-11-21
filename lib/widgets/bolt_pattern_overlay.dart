import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../vision/bolt_pattern.dart';

/// Aim circle, center dot, bore, and bolt holes. Coordinates are the full
/// upright frame. A square crop of that frame keeps the dot in the middle.
class BoltPatternOverlayPainter extends CustomPainter {
  const BoltPatternOverlayPainter(this.pattern);

  final BoltPattern? pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final guideCenter = Offset(size.width / 2, size.height / 2);
    final guideR = boltAimRadius * math.min(size.width, size.height);
    final guide = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(guideCenter, guideR, guide);
    final dot = Paint()..color = const Color(0xFFE85D04);
    canvas.drawCircle(guideCenter, 5, dot);
    canvas.drawLine(
      Offset(guideCenter.dx - 14, guideCenter.dy),
      Offset(guideCenter.dx - 7, guideCenter.dy),
      guide,
    );
    canvas.drawLine(
      Offset(guideCenter.dx + 7, guideCenter.dy),
      Offset(guideCenter.dx + 14, guideCenter.dy),
      guide,
    );
    canvas.drawLine(
      Offset(guideCenter.dx, guideCenter.dy - 14),
      Offset(guideCenter.dx, guideCenter.dy - 7),
      guide,
    );
    canvas.drawLine(
      Offset(guideCenter.dx, guideCenter.dy + 7),
      Offset(guideCenter.dx, guideCenter.dy + 14),
      guide,
    );

    final found = pattern;
    if (found == null) return;
    final center =
        Offset(found.centerX * size.width, found.centerY * size.height);
    final bore = Paint()
      ..color = const Color(0xFFE85D04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    _drawEllipse(
      canvas,
      center,
      found.boreRadius * size.width,
      found.aspect,
      found.axis,
      bore,
    );
    if (!found.hasBolts) return;
    final bolt = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final boltR = found.boltRadius * size.width;
    final ring = found.ringRadius * size.width;
    for (var i = 0; i < found.boltCount; i++) {
      final angle = found.rotation + i * math.pi * 2 / found.boltCount;
      final u = math.cos(angle) * ring;
      final v = math.sin(angle) * ring;
      final at = center +
          Offset(
            math.cos(found.axis) * u -
                math.sin(found.axis) * (v * found.aspect),
            math.sin(found.axis) * u +
                math.cos(found.axis) * (v * found.aspect),
          );
      _drawEllipse(canvas, at, boltR, found.aspect, found.axis, bolt);
    }
  }

  @override
  bool shouldRepaint(covariant BoltPatternOverlayPainter old) =>
      old.pattern != pattern;
}

void _drawEllipse(
  Canvas canvas,
  Offset center,
  double major,
  double aspect,
  double axis,
  Paint paint,
) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(axis);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: major * 2,
      height: major * 2 * aspect,
    ),
    paint,
  );
  canvas.restore();
}

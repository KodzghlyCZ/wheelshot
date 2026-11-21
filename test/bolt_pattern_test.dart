import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/vision/bolt_pattern.dart';

void main() {
  Uint8List squashY(Uint8List src, int w, int h, double aspect) {
    final out = Uint8List(w * h);
    final cy = (h - 1) / 2;
    for (var y = 0; y < h; y++) {
      final sy = (cy + (y - cy) / aspect).round();
      for (var x = 0; x < w; x++) {
        out[y * w + x] = (sy < 0 || sy >= h) ? 170 : src[sy * w + x];
      }
    }
    return out;
  }

  Uint8List rim({
    required int bolts,
    double rotation = 0.4,
  }) {
    const w = 240;
    const h = 320;
    final image = Uint8List(w * h)..fillRange(0, w * h, 170);
    void disk(double cx, double cy, double r, int color) {
      final r2 = r * r;
      for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
        for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= r2) image[y * w + x] = color;
        }
      }
    }

    const cx = 120.0;
    const cy = 160.0;
    disk(cx, cy, 34, 25);
    for (var i = 0; i < bolts; i++) {
      final angle = rotation + i * math.pi * 2 / bolts;
      disk(cx + math.cos(angle) * 78, cy + math.sin(angle) * 78, 9, 20);
    }
    return image;
  }

  test('five equal holes around a bore', () {
    final found = detectUprightLuma(rim(bolts: 5), 240, 320);
    expect(found, isNotNull);
    expect(found!.boltCount, 5);
    expect(found.centerX, closeTo(0.5, 0.04));
    expect(found.centerY, closeTo(0.5, 0.04));
    expect(found.boreRadius, greaterThan(found.boltRadius));
    expect(found.aspect, greaterThan(0.97));
  });

  test('count stays on the real spacing, not every other hole', () {
    expect(detectUprightLuma(rim(bolts: 6), 240, 320)?.boltCount, 6);
    expect(detectUprightLuma(rim(bolts: 4), 240, 320)?.boltCount, 4);
    expect(detectUprightLuma(rim(bolts: 3, rotation: 0.2), 240, 320)?.boltCount,
        3);
    expect(detectUprightLuma(rim(bolts: 7), 240, 320)?.boltCount, 7);
    expect(detectUprightLuma(rim(bolts: 8), 240, 320)?.boltCount, 8);
  });

  test('ten degrees of tilt still counts the holes', () {
    final round = rim(bolts: 5);
    final tilted = squashY(round, 240, 320, math.cos(10 * math.pi / 180));
    final found = detectUprightLuma(tilted, 240, 320);
    expect(found, isNotNull);
    expect(found!.boltCount, 5);
    expect(found.aspect, greaterThan(0.97));
  });

  test('bolt count waits before it flips', () {
    final hold = BoltPatternHold();
    BoltPattern at(int count) => BoltPattern(
          centerX: 0.5,
          centerY: 0.5,
          boreRadius: 0.1,
          boltCount: count,
          boltRadius: 0.02,
          ringRadius: 0.2,
          rotation: 0,
          score: 70,
        );
    expect(hold.push(at(5))!.boltCount, 5);
    expect(hold.push(at(3))!.boltCount, 5);
    expect(hold.push(at(3))!.boltCount, 5);
    expect(hold.push(at(3))!.boltCount, 5);
    expect(hold.push(at(3))!.boltCount, 3);
    expect(hold.push(at(5))!.boltCount, 3);
    expect(hold.push(null)?.boltCount, 3);
  });

  test('holes outside the aim circle are ignored', () {
    const w = 240;
    const h = 320;
    final image = Uint8List(w * h)..fillRange(0, w * h, 170);
    void disk(double cx, double cy, double r) {
      final r2 = r * r;
      for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
        for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
          if (x < 0 || y < 0 || x >= w || y >= h) continue;
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= r2) image[y * w + x] = 15;
        }
      }
    }

    disk(28, 28, 16);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      disk(28 + math.cos(angle) * 22, 28 + math.sin(angle) * 22, 5);
    }
    expect(detectUprightLuma(image, w, h), isNull);
  });

  test('a flat frame has no bore', () {
    final flat = Uint8List(240 * 320)..fillRange(0, 240 * 320, 140);
    expect(detectUprightLuma(flat, 240, 320), isNull);
  });

  test('sensor rotation 90 turns the buffer upright', () {
    final src = Uint8List.fromList([0, 1, 2, 3]);
    final turned = rotateLuma(src, 2, 2, 90);
    expect(turned.width, 2);
    expect(turned.height, 2);
    expect(turned.bytes, [2, 0, 3, 1]);
  });
}

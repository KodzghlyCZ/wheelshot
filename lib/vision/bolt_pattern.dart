import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// One center bore, plus 3–8 equal bolt holes on a circle around it.
class BoltPattern {
  const BoltPattern({
    required this.centerX,
    required this.centerY,
    required this.boreRadius,
    required this.boltCount,
    required this.boltRadius,
    required this.ringRadius,
    required this.rotation,
    required this.score,
    this.aspect = 1,
    this.axis = 0,
  });

  /// Center, as a fraction of the upright frame (0–1).
  final double centerX;
  final double centerY;

  /// Radii as a fraction of the upright frame width.
  final double boreRadius;
  final double boltRadius;
  final double ringRadius;

  /// 0 when only the bore is locked. Otherwise 3–8.
  final int boltCount;

  /// Radians, angle of the first bolt in the untilted plane. 0 points right.
  final double rotation;
  final double score;

  /// Minor / major of the shared ellipse. 1 is straight-on. Below 1 the
  /// camera is tilted, so the round holes project as ellipses.
  final double aspect;

  /// Radians of the ellipse major axis. 0 points right.
  final double axis;

  bool get hasBolts => boltCount >= 3;
}

/// Aim circle, as a fraction of the shorter upright side.
/// The bore sits on the center. Bolt holes stay inside the circle.
const boltAimRadius = 0.38;

class _Luma {
  const _Luma(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Copy, rotate into the upright preview, and fit the bolt pattern.
///
/// [sensorOrientation] is the clockwise angle Android says the buffer needs
/// so it matches the phone held upright.
Future<BoltPattern?> analyzeCameraFrame(
    CameraImage image, int sensorOrientation) {
  final plane = image.planes.first;
  final packed = _packPlane(
    plane.bytes,
    image.width,
    image.height,
    plane.bytesPerRow,
  );
  final small = _shrink(_Luma(packed, image.width, image.height));
  final upright = rotateLuma(
    small.bytes,
    small.width,
    small.height,
    sensorOrientation,
  );
  return compute(
    _detectBoltPattern,
    _Luma(upright.bytes, upright.width, upright.height),
  );
}

Uint8List _packPlane(Uint8List bytes, int width, int height, int stride) {
  final out = Uint8List(width * height);
  final row = stride <= 0 ? width : stride;
  for (var y = 0; y < height; y++) {
    final from = y * row;
    if (from + width > bytes.length) break;
    out.setRange(y * width, y * width + width, bytes, from);
  }
  return out;
}

/// Rotate a tightly packed luma buffer clockwise by [degrees] (0/90/180/270).
({Uint8List bytes, int width, int height}) rotateLuma(
  Uint8List src,
  int width,
  int height,
  int degrees,
) {
  final turn = ((degrees % 360) + 360) % 360;
  if (turn == 0) return (bytes: src, width: width, height: height);
  final destW = turn == 180 ? width : height;
  final destH = turn == 180 ? height : width;
  final out = Uint8List(destW * destH);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final lateX = switch (turn) {
        90 => height - 1 - y,
        180 => width - 1 - x,
        _ => y,
      };
      final lateY = switch (turn) {
        90 => x,
        180 => height - 1 - y,
        _ => width - 1 - x,
      };
      out[lateY * destW + lateX] = src[y * width + x];
    }
  }
  return (bytes: out, width: destW, height: destH);
}

/// Fit on an upright luma frame. Null when no dark center bore is found.
BoltPattern? detectUprightLuma(Uint8List bytes, int width, int height) {
  return _detectBoltPattern(_Luma(bytes, width, height));
}

/// Fit on an upright luma frame. Null when no dark center bore is found.
///
/// Only the aim circle is searched. A rim tilted up to 10° projects as a
/// mild ellipse (minor/major = cos of the tilt). That warp may refine the
/// same bolt count. It does not get to pick a different count.
BoltPattern? _detectBoltPattern(_Luma frame) {
  final small = _shrink(frame);
  final crop = _cropAim(small);
  _TiltFit? faceOn;
  _TiltFit? best;
  // 10° from straight-on. Wider ellipses were drawing a strong squash and
  // turning a 5-lug hub into a 3-count.
  final tilted = math.cos(10 * math.pi / 180);
  for (final aspect in [1.0, tilted]) {
    final axes = aspect == 1.0
        ? const [0.0]
        : const [0.0, math.pi / 4, math.pi / 2, 3 * math.pi / 4];
    for (final axis in axes) {
      final warped =
          aspect == 1.0 ? crop.luma : _unwarp(crop.luma, aspect, axis);
      final fit = _fitCircles(warped);
      if (fit == null) continue;
      final tilt = _TiltFit(fit, aspect, axis);
      if (aspect == 1.0) {
        faceOn = tilt;
        best = tilt;
      } else {
        final straight = faceOn?.fit.bolts;
        final warpedBolts = fit.bolts;
        if (straight != null &&
            warpedBolts != null &&
            warpedBolts.count == straight.count &&
            fit.score > faceOn!.score) {
          best = tilt;
        }
      }
    }
  }
  if (best == null) return null;
  return _placeOnFrame(best, crop, small);
}

/// Holds the bolt count until a different count repeats.
///
/// One noisy frame used to flip the overlay between 5 and 3.
class BoltPatternHold {
  BoltPattern? _shown;
  var _misses = 0;
  var _pendingCount = -1;
  var _pendingHits = 0;

  /// Frames a new count must repeat before it replaces the one on screen.
  static const settleFrames = 4;

  BoltPattern? push(BoltPattern? next) {
    if (next == null) {
      _misses++;
      _pendingHits = 0;
      _pendingCount = -1;
      if (_misses >= settleFrames) _shown = null;
      return _shown;
    }
    _misses = 0;
    final count = next.boltCount;
    if (_shown == null || _shown!.boltCount == count) {
      _pendingCount = count;
      _pendingHits = 0;
      _shown = next;
      return _shown;
    }
    if (count == _pendingCount) {
      _pendingHits++;
    } else {
      _pendingCount = count;
      _pendingHits = 1;
    }
    if (_pendingHits >= settleFrames) {
      _shown = next;
      _pendingHits = 0;
    }
    return _shown;
  }
}

class _Crop {
  const _Crop(this.luma, this.left, this.top);
  final _Luma luma;
  final int left;
  final int top;
}

class _Fit {
  const _Fit(this.bore, this.bolts);
  final _Circle bore;
  final _Bolts? bolts;
  double get score => bolts?.score ?? bore.score * 0.25;
}

class _TiltFit {
  const _TiltFit(this.fit, this.aspect, this.axis);
  final _Fit fit;
  final double aspect;
  final double axis;
  double get score => fit.score;
}

_Crop _cropAim(_Luma frame) {
  final minSide = math.min(frame.width, frame.height);
  final rad = math.max(12, (boltAimRadius * minSide).round());
  final side = rad * 2;
  final left = (frame.width ~/ 2) - rad;
  final top = (frame.height ~/ 2) - rad;
  final out = Uint8List(side * side);
  final r2 = rad * rad;
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final dx = x - rad;
      final dy = y - rad;
      final sx = left + x;
      final sy = top + y;
      final inside = dx * dx + dy * dy <= r2 &&
          sx >= 0 &&
          sy >= 0 &&
          sx < frame.width &&
          sy < frame.height;
      out[y * side + x] = inside ? frame.bytes[sy * frame.width + sx] : 128;
    }
  }
  return _Crop(_Luma(out, side, side), left, top);
}

/// Stretch a tilted ellipse back toward a circle. [aspect] is minor/major.
_Luma _unwarp(_Luma src, double aspect, double axis) {
  final w = src.width;
  final h = src.height;
  final out = Uint8List(w * h);
  final cx = (w - 1) / 2;
  final cy = (h - 1) / 2;
  final cosA = math.cos(axis);
  final sinA = math.sin(axis);
  for (var y = 0; y < h; y++) {
    final v = y - cy;
    for (var x = 0; x < w; x++) {
      final u = x - cx;
      final sx = cx + cosA * u - sinA * (v * aspect);
      final sy = cy + sinA * u + cosA * (v * aspect);
      final ix = sx.round();
      final iy = sy.round();
      out[y * w + x] = (ix < 0 || iy < 0 || ix >= w || iy >= h)
          ? 128
          : src.bytes[iy * w + ix];
    }
  }
  return _Luma(out, w, h);
}

_Fit? _fitCircles(_Luma frame) {
  final bore = _findBore(frame);
  if (bore == null) return null;
  return _Fit(bore, _findBolts(frame, bore));
}

BoltPattern _placeOnFrame(_TiltFit tilt, _Crop crop, _Luma small) {
  final fit = tilt.fit;
  final halfW = crop.luma.width / 2;
  final halfH = crop.luma.height / 2;
  final u = fit.bore.cx - halfW;
  final v = fit.bore.cy - halfH;
  final cosA = math.cos(tilt.axis);
  final sinA = math.sin(tilt.axis);
  final ix = crop.left + halfW + cosA * u - sinA * (v * tilt.aspect);
  final iy = crop.top + halfH + sinA * u + cosA * (v * tilt.aspect);
  final bolts = fit.bolts;
  return BoltPattern(
    centerX: ix / small.width,
    centerY: iy / small.height,
    boreRadius: fit.bore.radius / small.width,
    boltCount: bolts?.count ?? 0,
    boltRadius: (bolts?.radius ?? 0) / small.width,
    ringRadius: (bolts?.ring ?? 0) / small.width,
    rotation: bolts?.rotation ?? 0,
    score: bolts?.score ?? fit.bore.score,
    aspect: tilt.aspect,
    axis: tilt.axis,
  );
}

class _Circle {
  const _Circle(this.cx, this.cy, this.radius, this.score);
  final double cx;
  final double cy;
  final double radius;
  final double score;
}

class _Bolts {
  const _Bolts(this.count, this.radius, this.ring, this.rotation, this.score);
  final int count;
  final double radius;
  final double ring;
  final double rotation;
  final double score;
}

_Luma _shrink(_Luma frame) {
  const maxSide = 200;
  final side = math.max(frame.width, frame.height);
  if (side <= maxSide) return frame;
  final scale = maxSide / side;
  final dw = math.max(16, (frame.width * scale).round());
  final dh = math.max(16, (frame.height * scale).round());
  final out = Uint8List(dw * dh);
  for (var y = 0; y < dh; y++) {
    final sy = math.min(frame.height - 1, (y * frame.height / dh).floor());
    for (var x = 0; x < dw; x++) {
      final sx = math.min(frame.width - 1, (x * frame.width / dw).floor());
      out[y * dw + x] = frame.bytes[sy * frame.width + sx];
    }
  }
  return _Luma(out, dw, dh);
}

_Circle? _findBore(_Luma frame) {
  final w = frame.width;
  final h = frame.height;
  final minSide = math.min(w, h);
  _Circle? best;
  final x0 = (w * 0.38).round();
  final x1 = (w * 0.62).round();
  final y0 = (h * 0.38).round();
  final y1 = (h * 0.62).round();
  final step = math.max(3, minSide ~/ 28);
  for (var y = y0; y <= y1; y += step) {
    for (var x = x0; x <= x1; x += step) {
      for (var r = (minSide * 0.06).round();
          r <= (minSide * 0.24).round();
          r += step) {
        final contrast =
            _holeContrast(frame, x.toDouble(), y.toDouble(), r.toDouble());
        if (contrast == null || contrast < 16) continue;
        // Contrast first. Radius only breaks a tie so a speck does not
        // beat the bore the aim dot is sitting on.
        final dx = x / w - 0.5;
        final dy = y / h - 0.5;
        final dist = math.sqrt(dx * dx + dy * dy);
        final score =
            contrast * (0.75 + 0.25 * r / (minSide * 0.24)) * (1.15 - dist);
        if (best == null || score > best.score) {
          best = _Circle(x.toDouble(), y.toDouble(), r.toDouble(), score);
        }
      }
    }
  }
  return best;
}

/// Bolt count is the period of the ring around the bore: hole, gap, hole.
/// A harmonic votes only when the gaps between its holes are not holes too,
/// so a 6-lug ring is not read as 3.
_Bolts? _findBolts(_Luma frame, _Circle bore) {
  final minSide = math.min(frame.width, frame.height).toDouble();
  final power = List<double>.filled(9, 0);
  final best = List<_Bolts?>.filled(9, null);
  final rMin = math.max(3.0, bore.radius * 0.18);
  final rMax = math.max(rMin, bore.radius * 0.55);
  for (var radius = rMin;
      radius <= rMax;
      radius += math.max(1.0, rMin * 0.35)) {
    final ringMin = bore.radius + radius + 2;
    final ringMax = minSide * 0.46;
    if (ringMin >= ringMax) continue;
    final ringStep = math.max(3.0, (ringMax - ringMin) / 6);
    for (var ring = ringMin; ring <= ringMax; ring += ringStep) {
      final profile = _angularContrast(
        frame,
        bore.cx,
        bore.cy,
        ring,
        radius,
      );
      if (profile == null) continue;
      final harms = List<({double amp, double rotation})?>.filled(9, null);
      var maxAmp = 0.0;
      for (var count = 3; count <= 8; count++) {
        final harm = _harmonic(profile, count);
        harms[count] = harm;
        if (harm.amp > maxAmp) maxAmp = harm.amp;
      }
      // Flat rings are noise. They must not vote.
      if (maxAmp < 4) continue;
      for (var count = 3; count <= 8; count++) {
        final harm = harms[count]!;
        if (harm.amp < maxAmp * 0.55) continue;
        final score = _patternScore(
          frame,
          bore.cx,
          bore.cy,
          ring,
          radius,
          count,
          harm.rotation,
        );
        // Below this, Commons hubs were an accidental period on the wrong ring.
        // The clear 5-lug photos all land higher.
        if (score == null || score < 32) continue;
        power[count] += harm.amp;
        final prior = best[count];
        if (prior == null || score > prior.score) {
          best[count] = _Bolts(count, radius, ring, harm.rotation, score);
        }
      }
    }
  }
  var winner = 0;
  var bestPower = 0.0;
  var secondPower = 0.0;
  for (var count = 3; count <= 8; count++) {
    final p = power[count];
    if (p > bestPower) {
      secondPower = bestPower;
      bestPower = p;
      winner = count;
    } else if (p > secondPower) {
      secondPower = p;
    }
  }
  final chosen = best[winner];
  if (chosen == null || bestPower <= 0) return null;
  // Two periods close together is not a count yet.
  if (secondPower > 0 && bestPower < secondPower * 1.35) return null;
  return chosen;
}

/// Hole-contrast sampled once around the bore. High where a dark hole sits.
List<double>? _angularContrast(
  _Luma frame,
  double cx,
  double cy,
  double ring,
  double radius,
) {
  const samples = 72;
  final out = List<double>.filled(samples, 0);
  for (var i = 0; i < samples; i++) {
    final angle = i * math.pi * 2 / samples;
    final contrast = _holeContrast(
      frame,
      cx + math.cos(angle) * ring,
      cy + math.sin(angle) * ring,
      radius,
    );
    if (contrast == null) return null;
    out[i] = contrast;
  }
  return out;
}

/// Amplitude and angle of the first peak for [count] cycles per turn.
({double amp, double rotation}) _harmonic(List<double> profile, int count) {
  var cosSum = 0.0;
  var sinSum = 0.0;
  final n = profile.length;
  for (var i = 0; i < n; i++) {
    final angle = count * i * math.pi * 2 / n;
    cosSum += profile[i] * math.cos(angle);
    sinSum += profile[i] * math.sin(angle);
  }
  return (
    amp: math.sqrt(cosSum * cosSum + sinSum * sinSum) / n,
    rotation: math.atan2(sinSum, cosSum) / count,
  );
}

/// High when the [count] sites are dark holes and the gaps between them are not.
double? _patternScore(
  _Luma frame,
  double cx,
  double cy,
  double ring,
  double radius,
  int count,
  double rotation,
) {
  var holes = 0.0;
  var gaps = 0.0;
  var worstHole = 999.0;
  for (var i = 0; i < count; i++) {
    final holeA = rotation + i * math.pi * 2 / count;
    final gapA = holeA + math.pi / count;
    final hole = _holeContrast(
      frame,
      cx + math.cos(holeA) * ring,
      cy + math.sin(holeA) * ring,
      radius,
    );
    final gap = _holeContrast(
      frame,
      cx + math.cos(gapA) * ring,
      cy + math.sin(gapA) * ring,
      radius,
    );
    if (hole == null || gap == null) return null;
    holes += hole;
    gaps += gap;
    if (hole < worstHole) worstHole = hole;
  }
  if (worstHole < 8) return null;
  return holes / count - gaps / count;
}

/// Outside ring brighter than the disk. Null when the circle leaves the frame.
double? _holeContrast(_Luma frame, double cx, double cy, double radius) {
  if (radius < 2) return null;
  final inside = _mean(frame, cx, cy, radius * 0.55, 0);
  final outside = _mean(frame, cx, cy, radius * 1.45, radius * 1.12);
  if (inside == null || outside == null) return null;
  return outside - inside;
}

double? _mean(_Luma frame, double cx, double cy, double radius, double inner) {
  final w = frame.width;
  final h = frame.height;
  var sum = 0;
  var n = 0;
  void take(double x, double y) {
    final ix = x.round();
    final iy = y.round();
    if (ix < 0 || iy < 0 || ix >= w || iy >= h) return;
    sum += frame.bytes[iy * w + ix];
    n++;
  }

  if (inner <= 0) {
    take(cx, cy);
    const samples = 8;
    for (var i = 0; i < samples; i++) {
      final a = i * math.pi * 2 / samples;
      take(cx + math.cos(a) * radius, cy + math.sin(a) * radius);
    }
  } else {
    const samples = 8;
    for (var ring = 0; ring < 2; ring++) {
      final rr = inner + (radius - inner) * (ring + 0.5) / 2;
      for (var i = 0; i < samples; i++) {
        final a = (i + ring * 0.5) * math.pi * 2 / samples;
        take(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
      }
    }
  }
  if (n < 4) return null;
  return sum / n;
}

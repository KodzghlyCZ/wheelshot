import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'bolt_pattern.dart';

/// Four-digit DOT date: week 01–53, year 00–26 (matches the shoot dials).
class DotDate {
  const DotDate({required this.week, required this.year});

  final int week;
  final int year;

  String get label =>
      '${week.toString().padLeft(2, '0')}${year.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DotDate && other.week == week && other.year == year;

  @override
  int get hashCode => Object.hash(week, year);
}

final _fourDigits = RegExp(r'(?<!\d)(\d{4})(?!\d)');
final _spacedDigits = RegExp(r'(?<!\d)(\d)\s*(\d)\s*(\d)\s*(\d)(?!\d)');

/// Map OCR lookalikes to digits, but keep the literal word DOT intact.
@visibleForTesting
String normalizeDotOcrText(String raw) {
  final upper = raw.toUpperCase();
  final out = StringBuffer();
  var i = 0;
  while (i < upper.length) {
    if (i + 2 < upper.length && upper.startsWith('DOT', i)) {
      out.write('DOT');
      i += 3;
      continue;
    }
    final c = upper[i];
    out.write(switch (c) {
      'O' => '0',
      'I' || 'L' => '1',
      'S' => '5',
      'B' => '8',
      'Z' => '2',
      'G' => '6',
      _ => c,
    });
    i++;
  }
  return out.toString();
}

/// Pull every WWYY that fits the dial ranges.
List<DotDate> parseDotDates(String raw) {
  final text = normalizeDotOcrText(raw);
  final out = <DotDate>[];
  final seen = <String>{};
  void consider(String digits) {
    if (digits.length != 4) return;
    final week = int.tryParse(digits.substring(0, 2));
    final year = int.tryParse(digits.substring(2));
    if (week == null || year == null) return;
    if (week < 1 || week > 53) return;
    if (year < 0 || year > 26) return;
    if (!seen.add(digits)) return;
    out.add(DotDate(week: week, year: year));
  }

  for (final m in _fourDigits.allMatches(text)) {
    consider(m.group(1)!);
  }
  for (final m in _spacedDigits.allMatches(text)) {
    consider('${m.group(1)}${m.group(2)}${m.group(3)}${m.group(4)}');
  }
  return out;
}

/// Last valid WWYY in [raw]. Frame OCR only cares about the 4 digits.
DotDate? pickDotDate(String raw) {
  final all = parseDotDates(raw);
  if (all.isEmpty) return null;
  return all.last;
}

/// Same oval as [DotAimOverlayPainter] — OCR only feeds this crop to ML Kit.
Rect dotAimRect(Size size) {
  final center = Offset(size.width / 2, size.height * 0.52);
  final rx = size.width * 0.34;
  final ry = size.height * 0.11;
  return Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
}

/// Holds a DOT date until a different one repeats.
class DotDateHold {
  DotDate? _shown;
  var _misses = 0;
  String? _pending;
  var _pendingHits = 0;

  static const settleFrames = 3;

  DotDate? push(DotDate? next) {
    if (next == null) {
      _misses++;
      _pendingHits = 0;
      _pending = null;
      if (_misses >= settleFrames) _shown = null;
      return _shown;
    }
    _misses = 0;
    final label = next.label;
    if (_shown == null || _shown!.label == label) {
      _pending = label;
      _pendingHits = 0;
      _shown = next;
      return _shown;
    }
    if (label == _pending) {
      _pendingHits++;
    } else {
      _pending = label;
      _pendingHits = 1;
    }
    if (_pendingHits >= settleFrames) {
      _shown = next;
      _pendingHits = 0;
    }
    return _shown;
  }
}

/// Live ML Kit reader for the DOT oval.
class DotOcr {
  DotOcr()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  var _busy = false;

  Future<void> dispose() => _recognizer.close();

  /// Crops the upright aim oval, then OCR — ignores the rest of the frame.
  Future<DotDate?> analyze(
    CameraImage image, {
    required int sensorOrientation,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final plane = image.planes.first;
      final packed = _packY(
        plane.bytes,
        image.width,
        image.height,
        plane.bytesPerRow,
      );
      // Same upright transform as bolt pattern / CameraPreview.
      final upright = rotateLuma(
        packed,
        image.width,
        image.height,
        sensorOrientation,
      );
      final aim = dotAimRect(
        Size(upright.width.toDouble(), upright.height.toDouble()),
      );
      var crop = _cropLuma(upright.bytes, upright.width, upright.height, aim);
      if (crop == null) return null;
      // Embossed digits need pixels; upscale tiny crops.
      if (crop.width < 400) {
        crop = _scale2x(crop.bytes, crop.width, crop.height);
      }
      final nv21 = _lumaToNv21(crop.bytes, crop.width, crop.height);
      final input = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(crop.width.toDouble(), crop.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: crop.width,
        ),
      );
      return await _recognize(input);
    } catch (e, st) {
      // ignore: avoid_print
      print('DotOcr analyze $e\n$st');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Still / JPEG path for on-device checks (needs Android/iOS ML Kit).
  /// Treats the whole file as the 4-digit frame (use a crop, not a full tire).
  Future<DotDate?> analyzeFile(String path) async {
    if (_busy) return null;
    _busy = true;
    try {
      final input = InputImage.fromFilePath(path);
      return await _recognize(input);
    } catch (e, st) {
      // ignore: avoid_print
      print('DotOcr file $e\n$st');
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<DotDate?> _recognize(InputImage input) async {
    final recognized = await _recognizer.processImage(input);
    final raw = recognized.text.trim();
    if (raw.isNotEmpty) {
      // ignore: avoid_print
      print('DotOcr raw=$raw');
    }
    return pickDotDate(raw);
  }
}

Uint8List _packY(Uint8List bytes, int width, int height, int stride) {
  final out = Uint8List(width * height);
  final row = stride <= 0 ? width : stride;
  for (var y = 0; y < height; y++) {
    final from = y * row;
    if (from + width > bytes.length) break;
    out.setRange(y * width, y * width + width, bytes, from);
  }
  return out;
}

({Uint8List bytes, int width, int height})? _cropLuma(
  Uint8List src,
  int width,
  int height,
  Rect aim,
) {
  var left = aim.left.floor().clamp(0, width - 2).toInt() & ~1;
  var top = aim.top.floor().clamp(0, height - 2).toInt() & ~1;
  final right = aim.right.ceil().clamp(left + 2, width).toInt();
  final bottom = aim.bottom.ceil().clamp(top + 2, height).toInt();
  var cw = (right - left) & ~1;
  var ch = (bottom - top) & ~1;
  if (cw < 32 || ch < 16) return null;
  if (left + cw > width) cw = (width - left) & ~1;
  if (top + ch > height) ch = (height - top) & ~1;
  final out = Uint8List(cw * ch);
  for (var y = 0; y < ch; y++) {
    final from = (top + y) * width + left;
    out.setRange(y * cw, y * cw + cw, src, from);
  }
  return (bytes: out, width: cw, height: ch);
}

({Uint8List bytes, int width, int height}) _scale2x(
  Uint8List src,
  int width,
  int height,
) {
  final w2 = width * 2;
  final h2 = height * 2;
  final out = Uint8List(w2 * h2);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = src[y * width + x];
      final o = (y * 2) * w2 + x * 2;
      out[o] = v;
      out[o + 1] = v;
      out[o + w2] = v;
      out[o + w2 + 1] = v;
    }
  }
  return (bytes: out, width: w2, height: h2);
}

/// NV21 with neutral chroma — ML Kit text only needs luma.
Uint8List _lumaToNv21(Uint8List y, int width, int height) {
  final out = Uint8List(width * height + width * height ~/ 2);
  out.setRange(0, y.length, y);
  out.fillRange(y.length, out.length, 128);
  return out;
}

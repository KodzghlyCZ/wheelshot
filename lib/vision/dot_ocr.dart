import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

/// Same oval as [DotAimOverlayPainter] — OCR only accepts text inside this.
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

  /// Null when a previous frame is still running or the buffer is unusable.
  Future<DotDate?> analyze(
    CameraImage image, {
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final input = _inputImage(
        image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
      );
      if (input == null) return null;
      return await _recognize(
        input,
        imageSize: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );
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
      return await _recognize(input, frameOnly: true);
    } finally {
      _busy = false;
    }
  }

  Future<DotDate?> _recognize(
    InputImage input, {
    Size? imageSize,
    bool frameOnly = false,
  }) async {
    try {
      final recognized = await _recognizer.processImage(input);
      return _pickFromRecognized(
        recognized,
        imageSize: imageSize,
        frameOnly: frameOnly,
      );
    } catch (e, st) {
      debugPrint('DotOcr $e\n$st');
      return null;
    }
  }

  /// Only WWYY whose line center sits in the aim oval (live), or whole
  /// recognition when [frameOnly] (already-cropped still).
  DotDate? _pickFromRecognized(
    RecognizedText text, {
    Size? imageSize,
    bool frameOnly = false,
  }) {
    if (text.text.trim().isEmpty) return null;

    if (frameOnly || imageSize == null) {
      return pickDotDate(text.text);
    }

    final aim = dotAimRect(imageSize);
    DotDate? bestInAim;
    var bestArea = double.infinity;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        final picked = pickDotDate(line.text);
        if (picked == null) continue;
        final center = box.center;
        if (!aim.contains(center)) continue;
        final area = box.width * box.height;
        if (area < bestArea) {
          bestArea = area;
          bestInAim = picked;
        }
      }
    }
    return bestInAim;
  }

  InputImage? _inputImage(
    CameraImage image, {
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _rotation(sensorOrientation, deviceOrientation);
    if (rotation == null) return null;

    final nv21 = _yuv420ToNv21(image);
    if (nv21 == null) return null;

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  InputImageRotation? _rotation(
    int sensorOrientation,
    DeviceOrientation deviceOrientation,
  ) {
    const map = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final compensation = map[deviceOrientation];
    if (compensation == null) return null;
    // Back camera.
    final degrees = (sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }
}

/// Pack YUV_420_888 planes into a single NV21 buffer for ML Kit.
Uint8List? _yuv420ToNv21(CameraImage image) {
  if (image.planes.length < 3) {
    if (image.planes.length == 1) return image.planes.first.bytes;
    return null;
  }
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final yRowStride = yPlane.bytesPerRow;
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerRow == width
      ? 1
      : uPlane.bytesPerPixel ?? 2;

  final out = Uint8List(width * height + width * height ~/ 2);
  var o = 0;
  for (var row = 0; row < height; row++) {
    final start = row * yRowStride;
    out.setRange(o, o + width, yPlane.bytes, start);
    o += width;
  }

  final uvHeight = height ~/ 2;
  final uvWidth = width ~/ 2;
  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      final uvIndex = row * uvRowStride + col * uvPixelStride;
      // NV21 is VU interleaved.
      out[o++] = vPlane.bytes[uvIndex];
      out[o++] = uPlane.bytes[uvIndex];
    }
  }
  return out;
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/vision/bolt_pattern.dart';

/// Local-only. Photos live in /tmp/rims and are not part of the repo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('score public hub photos', () async {
    final dir = Directory('/tmp/rims');
    if (!dir.existsSync()) return;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final lines = <String>[];
    for (final file in files) {
      final luma = await _luma(file);
      final found = detectUprightLuma(luma.bytes, luma.width, luma.height);
      final name = file.uri.pathSegments.last;
      if (found == null) {
        lines.add('$name ${luma.width}x${luma.height} none');
        continue;
      }
      lines.add(
        '$name ${luma.width}x${luma.height} '
        'bolts=${found.boltCount} aspect=${found.aspect.toStringAsFixed(2)} '
        'score=${found.score.toStringAsFixed(1)} '
        'bore=${found.boreRadius.toStringAsFixed(3)} '
        'ring=${found.ringRadius.toStringAsFixed(3)} '
        'hole=${found.boltRadius.toStringAsFixed(3)}',
      );
    }
    File('/tmp/rims/results.txt').writeAsStringSync('${lines.join('\n')}\n');
    // ignore: avoid_print
    print(lines.join('\n'));

    int? bolts(String name) {
      final line = lines.firstWhere((l) => l.startsWith(name));
      final match = RegExp(r'bolts=(\d+)').firstMatch(line);
      return match == null ? null : int.parse(match.group(1)!);
    }

    expect(bolts('felgenschloss.jpg'), 5);
    expect(bolts('gallardo.jpg'), 5);
    expect(bolts('mustang.jpg'), 5);
    expect(bolts('landcruiser.jpg'), 0);
    expect(bolts('rays.jpg'), 0);
    expect(bolts('wheel-bolts.jpg'), 0);
  });
}

class _Gray {
  _Gray(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

Future<_Gray> _luma(File file) async {
  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: 480,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = image.width;
  final h = image.height;
  final out = Uint8List(w * h);
  final data = rgba!;
  for (var i = 0; i < w * h; i++) {
    final r = data.getUint8(i * 4);
    final g = data.getUint8(i * 4 + 1);
    final b = data.getUint8(i * 4 + 2);
    out[i] = ((r * 54 + g * 183 + b * 19) >> 8);
  }
  return _Gray(out, w, h);
}

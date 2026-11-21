import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/vision/dot_ocr.dart';

void main() {
  test('parses WWYY four digits', () {
    expect(pickDotDate('9C8N L5WT 0312')?.label, '0312');
    expect(pickDotDate('ab12 cd34 2712')?.label, '2712');
  });

  test('rejects impossible weeks', () {
    expect(parseDotDates('0099'), isEmpty);
    expect(parseDotDates('5412'), isEmpty);
  });

  test('accepts spaced digits', () {
    expect(pickDotDate('0 3 1 2')?.label, '0312');
  });

  test('O-as-zero glued after letter (RapidOCR DoT_Nummer)', () {
    expect(normalizeDotOcrText('TO312'), 'T0312');
    expect(pickDotDate('L5W TO312 9C8N')?.label, '0312');
  });

  test('frame pick is last WWYY only — no DOT hunt', () {
    // Noise before the oval digits must not require a DOT token.
    expect(pickDotDate('Plant Code 0312')?.label, '0312');
  });

  test('aim oval matches mid-frame 4-digit guide', () {
    final r = dotAimRect(const Size(1000, 1000));
    expect(r.center.dx, 500);
    expect(r.center.dy, 520);
    expect(r.width, 680);
    expect(r.height, 220);
  });

  test('hold settles a new date', () {
    final hold = DotDateHold();
    const a = DotDate(week: 3, year: 12);
    const b = DotDate(week: 27, year: 12);
    expect(hold.push(a)?.label, '0312');
    expect(hold.push(b)?.label, '0312');
    expect(hold.push(b)?.label, '0312');
    expect(hold.push(b)?.label, '2712');
  });
}

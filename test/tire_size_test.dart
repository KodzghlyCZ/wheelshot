import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/data/tire_size.dart';

void main() {
  test('formats prefix and suffix onto the sidewall size', () {
    expect(
      formatTireSize(
        prefix: 'T',
        width: 125,
        aspect: 80,
        construction: 'D',
        diameter: 16,
        suffix: '',
      ),
      'T125/80 D16',
    );
    expect(
      formatTireSize(
        prefix: '',
        width: 215,
        aspect: 65,
        construction: 'R',
        diameter: 16,
        suffix: 'C',
      ),
      '215/65 R16C',
    );
    expect(
      formatTireSize(
        prefix: 'LT',
        width: 245,
        aspect: 75,
        construction: 'R',
        diameter: 16,
        suffix: 'C',
      ),
      'LT245/75 R16C',
    );
  });

  test('parses spare, commercial, and plain sizes back onto the dials', () {
    final spare = tryParseTireSize('T125/80 D16');
    expect(spare?.prefix, 'T');
    expect(spare?.construction, 'D');
    expect(spare?.suffix, '');
    expect(spare?.diameter, 16);

    final van = tryParseTireSize('215/65 R16C');
    expect(van?.prefix, '');
    expect(van?.suffix, 'C');
    expect(van?.width, 215);

    final caravan = tryParseTireSize('185/75 R16 CP');
    expect(caravan?.suffix, 'CP');

    final plain = tryParseTireSize('225/40 R18 91Y');
    expect(plain?.prefix, '');
    expect(plain?.suffix, '');
    expect(plain?.diameter, 18);

    final truck = tryParseTireSize('LT245/75R16');
    expect(truck?.prefix, 'LT');
    expect(truck?.construction, 'R');

    expect(tryParseTireSize('not a size'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/models/session_specs.dart';
import 'package:wheelshot/models/shoot_plan.dart';

void main() {
  test('one rim + two tires writes separate sections', () {
    final out = const SessionSpecs(
      rims: [
        RimSpecs(brand: 'VW', pcd: '5x112', et: 'ET51', centerBore: '57.1'),
      ],
      tires: [
        TireSpecs(brand: 'Dunlop', size: '225/40 R18'),
        TireSpecs(brand: 'Michelin', size: '225/45 R18'),
      ],
    ).toFileContents(
      category: ShootCategory.wheelSet,
      config: const ShootConfig(pieceCount: 4, tireTypes: 2, rimTypes: 1),
    );

    expect(out, contains('rim_brand: VW'));
    expect(out, contains('center_bore: 57.1'));
    expect(out, contains('et: ET51'));
    expect(out, contains('tire1_tire_brand: Dunlop'));
    expect(out, contains('tire2_tire_brand: Michelin'));
    // Must not duplicate rim under tire2
    expect(RegExp(r'rim_brand:').allMatches(out).length, 1);
  });

  test('empty et omitted', () {
    final out = const SessionSpecs(
      rims: [RimSpecs(brand: 'Ronal')],
    ).toFileContents(category: ShootCategory.rimsOnly);

    expect(out, contains('rim_brand: Ronal'));
    expect(out, isNot(contains('et:')));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/models/shoot_plan.dart';

void main() {
  test('4 identical: overall, one piece, one tire pair, one rim block', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset4(),
    );
    expect(
      steps.map((s) => s.id).toList(),
      [
        'set_overall',
        'piece_individual',
        'tires_size',
        'tires_tread',
        'tires_dot',
        'type1_rim_hub',
        'type1_rim_brand',
        'type1_rim_size',
        'type1_rim_et',
      ],
    );
    expect(steps[2].dials, ShotDials.tireSize);
    expect(steps[3].dials, ShotDials.tread);
    expect(steps[4].dials, ShotDials.dot);
    expect(steps[5].dials, ShotDials.hub);
    expect(steps[7].dials, ShotDials.rimSize);
    expect(steps[8].dials, ShotDials.et);
  });

  test('2 tire types share one size step and one DOT step', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: const ShootConfig(pieceCount: 4, tireTypes: 2, rimTypes: 1),
    );
    expect(steps.where((s) => s.dials == ShotDials.tireSize).length, 1);
    expect(steps.where((s) => s.dials == ShotDials.tread).length, 1);
    expect(steps.where((s) => s.dials == ShotDials.dot).length, 1);
    expect(steps.where((s) => s.id.endsWith('rim_et')).length, 1);
  });

  test('2+2: one piece shot, then two rim blocks', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset2plus2(),
    );
    expect(steps.where((s) => s.id == 'piece_individual').length, 1);
    expect(steps.where((s) => s.id.endsWith('rim_hub')).length, 2);
    expect(steps.where((s) => s.id.endsWith('rim_et')).length, 2);
  });

  test('1 piece skips the individual shot', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: const ShootConfig(pieceCount: 1, tireTypes: 1, rimTypes: 1),
    );
    expect(steps.first.id, 'set_overall');
    expect(steps.any((s) => s.id == 'piece_individual'), isFalse);
  });

  test('4-2 ET-only: shared hub, brand, size, then two ET', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset4minus2(),
      etNotes: const ['ET35', 'ET45'],
    );
    final ids = steps.map((s) => s.id).toList();
    expect(ids, contains('shared_rim_hub'));
    expect(ids, contains('shared_rim_brand'));
    expect(ids, contains('shared_rim_size'));
    expect(ids, isNot(contains('shared_rim_overall')));
    expect(ids, contains('type1_rim_et'));
    expect(ids, contains('type2_rim_et'));
    expect(
      steps.firstWhere((s) => s.id == 'type1_rim_et').hint,
      contains('ET35'),
    );
    expect(steps.firstWhere((s) => s.id == 'type2_rim_et').specIndex, 1);
  });

  test('rims only has no tire steps', () {
    final steps = buildWizard(
      category: ShootCategory.rimsOnly,
      config: const ShootConfig(pieceCount: 2, rimTypes: 2),
    );
    expect(steps.any((s) => s.dials == ShotDials.tireSize), isFalse);
    expect(steps.where((s) => s.id.endsWith('rim_hub')).length, 2);
    expect(steps.first.id, 'set_overall');
    expect(steps[1].id, 'piece_individual');
  });

  test('tires only: overall, piece, size, DOT', () {
    final steps = buildWizard(
      category: ShootCategory.tiresOnly,
      config: const ShootConfig(pieceCount: 3, tireTypes: 2, rimTypes: 3),
    );
    expect(
      steps.map((s) => s.id).toList(),
      [
        'set_overall',
        'piece_individual',
        'tires_size',
        'tires_tread',
        'tires_dot',
      ],
    );
  });

  test('spare is overall, size, DOT, and a rim block when mounted', () {
    final bare = buildWizard(category: ShootCategory.spare, spareHasRim: false);
    expect(
      bare.map((s) => s.id).toList(),
      ['set_overall', 'tires_size', 'tires_tread', 'tires_dot'],
    );
    final mounted =
        buildWizard(category: ShootCategory.spare, spareHasRim: true);
    expect(mounted.any((s) => s.id == '01_rim_hub'), isTrue);
    expect(mounted.any((s) => s.id == 'piece_individual'), isFalse);
  });
}

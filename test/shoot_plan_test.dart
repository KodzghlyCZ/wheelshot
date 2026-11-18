import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/models/shoot_plan.dart';

void main() {
  test('4 identical: set overall + tire details + rim', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset4(),
    );
    final ids = steps.map((s) => s.id).toList();
    expect(ids, contains('set_overall'));
    expect(ids, contains('type1_tire_surface'));
    expect(ids, isNot(contains('type1_tire_overall')));
    expect(ids, contains('type1_rim_et'));
  });

  test('2 tire types / 1 rim: one set overall, two tread blocks, one rim', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: const ShootConfig(pieceCount: 4, tireTypes: 2, rimTypes: 1),
    );
    expect(steps.where((s) => s.id == 'set_overall').length, 1);
    expect(steps.where((s) => s.id.endsWith('tire_overall')).length, 0);
    expect(steps.where((s) => s.id.endsWith('tire_surface')).length, 2);
    expect(steps.where((s) => s.id.endsWith('rim_et')).length, 1);
  });

  test('2+2: two tire details and two rims', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset2plus2(),
    );
    expect(steps.where((s) => s.id == 'set_overall').length, 1);
    expect(steps.where((s) => s.id.endsWith('tire_dot')).length, 2);
    expect(steps.where((s) => s.id.endsWith('rim_et')).length, 2);
  });

  test('single spare-like 1 piece 1 type still has tire overall', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: const ShootConfig(pieceCount: 1, tireTypes: 1, rimTypes: 1),
    );
    expect(steps.any((s) => s.id == 'set_overall'), isFalse);
    expect(steps.any((s) => s.id.endsWith('tire_overall')), isTrue);
  });

  test('4-2 ET-only: shared face + two ET', () {
    final steps = buildWizard(
      category: ShootCategory.wheelSet,
      config: ShootConfig.preset4minus2(),
      etNotes: const ['ET35', 'ET45'],
    );
    final ids = steps.map((s) => s.id).toList();
    expect(ids, contains('set_overall'));
    expect(ids, contains('shared_rim_overall'));
    expect(ids, contains('type1_rim_et'));
    expect(ids, contains('type2_rim_et'));
    expect(
      steps.firstWhere((s) => s.id == 'type1_rim_et').hint,
      contains('ET35'),
    );
  });

  test('rims only has no tire steps', () {
    final steps = buildWizard(
      category: ShootCategory.rimsOnly,
      config: const ShootConfig(pieceCount: 2, rimTypes: 2),
    );
    expect(steps.any((s) => s.id.contains('tire')), isFalse);
    expect(steps.where((s) => s.id.endsWith('rim_et')).length, 2);
  });

  test('tires only: set overall + two detail blocks', () {
    final steps = buildWizard(
      category: ShootCategory.tiresOnly,
      config: const ShootConfig(pieceCount: 3, tireTypes: 2, rimTypes: 3),
    );
    expect(steps.any((s) => s.id.contains('rim')), isFalse);
    expect(steps.where((s) => s.id == 'set_overall').length, 1);
    expect(steps.where((s) => s.id.endsWith('tire_dot')).length, 2);
  });
}

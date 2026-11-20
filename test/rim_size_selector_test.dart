import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/widgets/rim_spec_selectors.dart';

void main() {
  test('rim line keeps center bore beside ET', () {
    expect(
      formatRimSizeLine(width: 7.5, diameter: 18, et: 35, centerBore: 57.1),
      '7.5Jx18 ET35 CB57.1',
    );
    expect(
      formatRimSizeLine(width: 8, diameter: 18, et: 35, centerBore: null),
      '8Jx18 ET35',
    );
    expect(formatCb(66.45), '66.45');
  });

  testWidgets('center bore dial fits on the rim size row at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RimSizeSelector(
              width: 7.5,
              diameter: 18,
              et: 35,
              centerBore: 57.1,
              onWidthChanged: (_) {},
              onDiameterChanged: (_) {},
              onEtChanged: (_) {},
              onCenterBoreChanged: (_) {},
              onResetToDefaults: () {},
              onManualChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CB'), findsOneWidget);
    expect(find.text('57.1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

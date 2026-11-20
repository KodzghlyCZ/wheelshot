import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/services/app_update.dart';
import 'package:wheelshot/widgets/update_available_button.dart';

void main() {
  testWidgets('update icon shows an orange dot and opens the offer', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              UpdateAvailableButton(onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('update-available')), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.backgroundColor, UpdateAvailableButton.dot);
    expect(badge.label, isNull);

    await tester.tap(find.byKey(const ValueKey('update-available')));
    expect(taps, 1);
  });

  testWidgets('offer sheet names the version and the install action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateOfferSheet(
            offer: AppUpdateOffer(
              versionName: '1.1.5',
              versionCode: 7,
              apkUrl: 'https://example.invalid/wheelshot.apk',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Update 1.1.5+7'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
  });
}

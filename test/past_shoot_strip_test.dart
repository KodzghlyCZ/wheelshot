import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/services/session_store.dart';
import 'package:wheelshot/widgets/past_shoot_strip.dart';
import 'package:wheelshot/widgets/tire_size_selector.dart';

void main() {
  PastSession session(String name) => PastSession(
        name: name,
        path: '/tmp/$name',
        photoCount: 0,
        title: 'Wheel set (rim + tire)',
      );

  testWidgets('home strip keeps three thumbs and a grid when more exist', (
    tester,
  ) async {
    final names = ['a', 'b', 'c', 'd'];
    String? tapped;
    var all = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PastShootStrip(
            sessions: [for (final n in names) session(n)],
            onThumb: (s) => tapped = s.name,
            onShowAll: () => all++,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('past-thumb-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-thumb-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-thumb-d')), findsNothing);
    expect(find.byKey(const ValueKey('past-all')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('past-thumb-b')));
    expect(tapped, 'b');
    await tester.tap(find.byKey(const ValueKey('past-all')));
    expect(all, 1);
  });

  testWidgets('four thumbs fit a phone-width home row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PastShootStrip(
              sessions: [
                for (final n in ['a', 'b', 'c', 'd']) session(n)
              ],
              onThumb: (_) {},
              onShowAll: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid button stays hidden when three or fewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PastShootStrip(
            sessions: [session('only')],
            onThumb: (_) {},
            onShowAll: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('past-thumb-only')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-all')), findsNothing);
  });

  testWidgets('thumbnail sheet offers photos, specs, and open', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => PastEditSheet(session: session('roller_test')),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('roller_test'), findsOneWidget);
    await tester.tap(find.text('Specs'));
    await tester.pumpAndSettle();
    expect(result, 'specs');
  });

  testWidgets('tire size selector shows prefix, suffix, and the letter note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TireSizeSelector(
            prefix: 'T',
            width: 125,
            aspect: 80,
            construction: 'D',
            diameter: 16,
            suffix: 'C',
            onPrefixChanged: (_) {},
            onWidthChanged: (_) {},
            onAspectChanged: (_) {},
            onConstructionChanged: (_) {},
            onDiameterChanged: (_) {},
            onSuffixChanged: (_) {},
            onResetToDefaults: () {},
            onManualChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('T temporary spare · C commercial / van'), findsOneWidget);
    expect(find.text('CP'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: TireSizeSelector(
              prefix: 'ST',
              width: 225,
              aspect: 40,
              construction: 'ZR',
              diameter: 18,
              suffix: 'CP',
              onPrefixChanged: _noopString,
              onWidthChanged: _noopInt,
              onAspectChanged: _noopInt,
              onConstructionChanged: _noopString,
              onDiameterChanged: _noopInt,
              onSuffixChanged: _noopString,
              onResetToDefaults: _noop,
              onManualChanged: _noopNullable,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
void _noopString(String _) {}
void _noopInt(int _) {}
void _noopNullable(String? _) {}

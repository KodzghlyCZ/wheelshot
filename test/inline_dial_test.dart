import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheelshot/widgets/inline_dial.dart';

void main() {
  testWidgets('parent value change does not callback during build', (
    tester,
  ) async {
    final host = _Host();
    await tester.pumpWidget(MaterialApp(home: host));
    await tester.pump();

    final state = tester.state<_HostState>(find.byType(_Host));
    final callsBefore = state.calls;

    state.setState(() => state.value = 16);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(state.calls, callsBefore);
    expect(state.value, 16);
  });

  testWidgets('linked dial rebuild does not throw', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Linked()));
    await tester.pump();

    final state = tester.state<_LinkedState>(find.byType(_Linked));
    await tester.drag(find.byType(InlineDial<int>).first, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.width, isNot(225));

    state.setState(() {});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _Linked extends StatefulWidget {
  const _Linked();

  @override
  State<_Linked> createState() => _LinkedState();
}

class _LinkedState extends State<_Linked> {
  int width = 225;
  int aspect = 40;
  static final _widths = [for (var w = 125; w <= 335; w += 5) w];
  static final _aspects = [for (var a = 25; a <= 100; a += 5) a];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InlineDial<int>(
          values: _widths,
          value: width,
          labelOf: (w) => '$w',
          onChanged: (w) => setState(() {
            width = w;
            aspect = 45;
          }),
        ),
        InlineDial<int>(
          values: _aspects,
          value: aspect,
          labelOf: (a) => '$a',
          onChanged: (a) => setState(() => aspect = a),
        ),
      ],
    );
  }
}

class _Host extends StatefulWidget {
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int value = 18;
  int calls = 0;

  @override
  Widget build(BuildContext context) {
    return InlineDial<int>(
      values: [for (var d = 13; d <= 23; d++) d],
      value: value,
      labelOf: (d) => '$d',
      onChanged: (d) {
        calls++;
        setState(() => value = d);
      },
    );
  }
}

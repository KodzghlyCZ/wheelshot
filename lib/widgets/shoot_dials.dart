import 'package:flutter/material.dart';

import '../data/rim_catalog.dart';
import '../models/shoot_plan.dart';
import '../models/spec_draft.dart';
import 'inline_dial.dart';
import 'rim_spec_selectors.dart';
import 'tire_size_selector.dart';

/// Spec dials for the current shot. Two or more selectors stay clipped
/// until the arrow opens the stack.
class ShootDialArea extends StatefulWidget {
  const ShootDialArea({
    super.key,
    required this.stepId,
    required this.child,
  });

  final String stepId;
  final Widget child;

  @override
  State<ShootDialArea> createState() => _ShootDialAreaState();
}

class _ShootDialAreaState extends State<ShootDialArea> {
  final _scroll = ScrollController();
  var _open = false;
  var _clipped = false;

  @override
  void didUpdateWidget(ShootDialArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepId != widget.stepId) {
      _open = false;
      _clipped = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _open) return;
      final overflow = _scroll.position.maxScrollExtent > 1;
      if (overflow != _clipped) setState(() => _clipped = overflow);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final showArrow = _clipped || _open;
    return Stack(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _open ? 480 : 176),
            child: ClipRect(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const NeverScrollableScrollPhysics(),
                child: widget.child,
              ),
            ),
          ),
        ),
        if (showArrow)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: _open ? 'Collapse dials' : 'Expand dials',
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
            ),
          ),
      ],
    );
  }
}

class ShootDialBody extends StatelessWidget {
  const ShootDialBody({
    super.key,
    required this.step,
    required this.draft,
    required this.onChanged,
  });

  final ShotStep step;
  final SpecDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (step.dials) {
      ShotDials.tireSize => _tires(size: true),
      ShotDials.tread => _tread(),
      ShotDials.dot => _tires(size: false),
      ShotDials.hub => _hub(),
      ShotDials.rimSize => _rimSize(),
      ShotDials.et => _et(),
      ShotDials.none => const SizedBox.shrink(),
    };
  }

  Widget _tires({required bool size}) {
    return Column(
      children: [
        for (var i = 0; i < draft.tires.length; i++)
          size ? _tireSize(i) : _dot(i),
      ],
    );
  }

  Widget _tireSize(int i) {
    final t = draft.tires[i];
    final selector = TireSizeSelector(
      prefix: t.prefix,
      width: t.width,
      aspect: t.aspect,
      construction: t.construction,
      diameter: t.diameter,
      suffix: t.suffix,
      reportLive: true,
      onPrefixChanged: (v) => _set(() => t.prefix = v),
      onWidthChanged: (v) => _set(() => t.width = v),
      onAspectChanged: (v) => _set(() => t.aspect = v),
      onConstructionChanged: (v) => _set(() => t.construction = v),
      onDiameterChanged: (v) => _set(() => t.diameter = v),
      onSuffixChanged: (v) => _set(() => t.suffix = v),
      onResetToDefaults: () => _set(() {
        t.prefix = '';
        t.width = 225;
        t.aspect = 40;
        t.construction = 'R';
        t.diameter = 18;
        t.suffix = '';
        t.sizeManual = null;
      }),
      onManualChanged: (v) => _set(() => t.sizeManual = v),
      onDuplicate: i + 1 < draft.tires.length
          ? () => _set(() => _copyTire(t, draft.tires[i + 1]))
          : null,
    );
    if (draft.tires.length < 2) return selector;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Type ${i + 1}'),
        selector,
      ],
    );
  }

  Widget _tread() {
    return Column(
      children: [
        for (var i = 0; i < draft.tires.length; i++)
          for (var d = 0; d < draft.tires[i].treadDepths.length; d++)
            _treadDial(i, d),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Add tread depth',
            onPressed: draft.tires.isEmpty
                ? null
                : () => _set(() {
                      final last = draft.tires.last;
                      final seed = last.treadDepths.isEmpty
                          ? 3.0
                          : last.treadDepths.last;
                      last.treadDepths.add(seed);
                    }),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _treadDial(int i, int d) {
    final t = draft.tires[i];
    final depth = t.treadDepths[d];
    final multi = draft.tires.length > 1 || t.treadDepths.length > 1;
    final label = multi
        ? 'Tread ${draft.tires.length > 1 ? 'type ${i + 1} · ' : ''}${d + 1}'
        : 'Tread depth (mm)';
    return DialStrip(
      label: label,
      manualHint: 'e.g. 4.5',
      dialText: () => depth.toStringAsFixed(1),
      onResetToDefaults: () => _set(() => t.treadDepths[d] = 3.0),
      onManualChanged: (v) {
        if (v == null) return;
        final n = double.tryParse(v.replaceAll(',', '.'));
        if (n != null) _set(() => t.treadDepths[d] = n);
      },
      children: [
        InlineDial<double>(
          values: [for (var mm = 0; mm <= 40; mm++) mm / 2],
          value: _nearestTread(depth),
          width: 72,
          labelOf: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _set(() => t.treadDepths[d] = v),
          reportLive: true,
        ),
      ],
    );
  }

  Widget _dot(int i) {
    final t = draft.tires[i];
    final label = draft.tires.length > 1 ? 'DOT · type ${i + 1}' : 'DOT';
    return DialStrip(
      label: label,
      manualHint: 'e.g. 2323',
      dialText: () => t.dotLabel,
      onResetToDefaults: () => _set(() {
        t.dotWeek = 1;
        t.dotYear = 23;
        t.dotManual = null;
      }),
      onManualChanged: (v) => _set(() => t.dotManual = v),
      onDuplicate: i + 1 < draft.tires.length
          ? () => _set(() {
                draft.tires[i + 1].dotWeek = t.dotWeek;
                draft.tires[i + 1].dotYear = t.dotYear;
                draft.tires[i + 1].dotManual = t.dotManual;
              })
          : null,
      children: [
        InlineDial<int>(
          values: [for (var w = 1; w <= 53; w++) w],
          value: t.dotWeek,
          width: 52,
          labelOf: (w) => w.toString().padLeft(2, '0'),
          onChanged: (w) => _set(() => t.dotWeek = w),
          reportLive: true,
        ),
        const DialSep('/'),
        InlineDial<int>(
          values: [for (var y = 0; y <= 26; y++) y],
          value: t.dotYear,
          width: 52,
          labelOf: (y) => y.toString().padLeft(2, '0'),
          onChanged: (y) => _set(() => t.dotYear = y),
          reportLive: true,
        ),
      ],
    );
  }

  Widget _hub() {
    final r = _rim;
    if (r == null) return const SizedBox.shrink();
    return Column(
      children: [
        PcdSelector(
          bolts: r.pcdBolts,
          diameter: r.pcdDiameter,
          reportLive: true,
          onBoltsChanged: (v) => _set(() {
            r.pcdBolts = v;
            r.pcdManual = null;
          }),
          onDiameterChanged: (v) => _set(() {
            r.pcdDiameter = v;
            r.pcdManual = null;
          }),
          onResetToDefaults: () => _set(() {
            r.pcdBolts = 5;
            r.pcdDiameter = 112;
            r.pcdManual = null;
          }),
          onManualChanged: (v) => _set(() => r.pcdManual = v),
        ),
        DialStrip(
          label: 'CB',
          manualHint: 'e.g. 57.1',
          dialText: () => r.centerBore == null ? '' : _mm(r.centerBore!),
          onResetToDefaults: () => _set(() => r.centerBore = 57.1),
          onManualChanged: (v) {
            if (v == null) return;
            final n = double.tryParse(v.replaceAll(',', '.'));
            if (n != null) _set(() => r.centerBore = n);
          },
          children: [
            InlineDial<double?>(
              values: const [null, ...kCommonCenterBores],
              value: kCommonCenterBores.contains(r.centerBore)
                  ? r.centerBore
                  : null,
              width: 72,
              labelOf: (b) => b == null ? '–' : _mm(b),
              onChanged: (v) => _set(() => r.centerBore = v),
              reportLive: true,
            ),
          ],
        ),
        EtSelector(
          et: r.et,
          reportLive: true,
          onChanged: (v) => _set(() => r.et = v),
          onResetToDefaults: () => _set(() => r.et = 35),
          onManualChanged: (v) {
            if (v == null) return;
            final n = int.tryParse(v.replaceAll(RegExp(r'[^\d-]'), ''));
            if (n != null && kEtValues.contains(n)) _set(() => r.et = n);
          },
        ),
      ],
    );
  }

  Widget _rimSize() {
    final r = _rim;
    if (r == null) return const SizedBox.shrink();
    return DialStrip(
      label: 'Rim size',
      manualHint: 'e.g. 7.5Jx18',
      dialText: () => formatRimSize(r.width, r.diameter),
      onResetToDefaults: () => _set(() {
        r.width = 7.5;
        r.diameter = 18;
        r.sizeManual = null;
      }),
      onManualChanged: (v) => _set(() => r.sizeManual = v),
      children: [
        InlineDial<double>(
          values: kRimWidths,
          value: r.width,
          width: 52,
          labelOf: _mm,
          onChanged: (v) => _set(() => r.width = v),
          reportLive: true,
        ),
        const DialSep('Jx'),
        InlineDial<int>(
          values: kRimDiameters,
          value: r.diameter,
          width: 48,
          labelOf: (d) => '$d',
          onChanged: (v) => _set(() => r.diameter = v),
          reportLive: true,
        ),
      ],
    );
  }

  Widget _et() {
    final r = _rim;
    if (r == null) return const SizedBox.shrink();
    return EtSelector(
      et: r.et,
      reportLive: true,
      onChanged: (v) => _set(() => r.et = v),
      onResetToDefaults: () => _set(() => r.et = 35),
      onManualChanged: (v) {
        if (v == null) return;
        final n = int.tryParse(v.replaceAll(RegExp(r'[^\d-]'), ''));
        if (n != null && kEtValues.contains(n)) _set(() => r.et = n);
      },
    );
  }

  RimDraft? get _rim {
    final i = step.specIndex;
    if (i < 0 || i >= draft.rims.length) return null;
    return draft.rims[i];
  }

  void _set(VoidCallback change) {
    change();
    onChanged();
  }

  void _copyTire(TireDraft from, TireDraft to) {
    to.prefix = from.prefix;
    to.width = from.width;
    to.aspect = from.aspect;
    to.construction = from.construction;
    to.diameter = from.diameter;
    to.suffix = from.suffix;
    to.sizeManual = from.sizeManual;
  }
}

double _nearestTread(double v) {
  final steps = [for (var mm = 0; mm <= 40; mm++) mm / 2.0];
  var best = steps.first;
  for (final s in steps) {
    if ((s - v).abs() < (best - v).abs()) best = s;
  }
  return best;
}

String _mm(double d) => d == d.roundToDouble()
    ? d.toInt().toString()
    : ((d * 100).round() % 10 == 0
        ? d.toStringAsFixed(1)
        : d.toStringAsFixed(2));

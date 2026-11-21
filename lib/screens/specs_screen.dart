import 'package:flutter/material.dart';

import '../data/rim_catalog.dart';
import '../data/tire_catalog.dart';
import '../data/tire_size.dart';
import '../data/tire_size_combos.dart';
import '../models/session_specs.dart';
import '../models/shoot_plan.dart';
import '../services/session_store.dart';
import '../widgets/confirm_leave.dart';
import '../widgets/inline_dial.dart';
import '../widgets/rim_spec_selectors.dart';
import '../widgets/suggest_field.dart';
import '../widgets/tire_size_selector.dart';
import 'done_screen.dart';

class SpecsScreen extends StatefulWidget {
  const SpecsScreen({super.key, required this.store});

  final SessionStore store;

  @override
  State<SpecsScreen> createState() => _SpecsScreenState();
}

class _SpecsScreenState extends State<SpecsScreen> {
  late final List<_RimControllers> _rims;
  late final List<_TireControllers> _tires;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  ShootCategory get _cat => widget.store.category;
  ShootConfig? get _config => widget.store.config;

  static final _treadValues = [
    for (var t = 0; t <= 20; t++) t / 2,
  ];
  static final _dotWeeks = [for (var w = 1; w <= 53; w++) w];
  static final _dotYears = [for (var y = 0; y <= 26; y++) y];
  @override
  void initState() {
    super.initState();
    final cfg = _config;
    final rimN = _cat.includesRim
        ? (cfg?.rimSpecSlots ?? 1)
        : (_cat == ShootCategory.spare && widget.store.spareHasRim ? 1 : 0);
    final tireN = _cat.includesTire ? (cfg?.tireSpecSlots ?? 1) : 0;
    _rims = List.generate(rimN, (_) => _RimControllers());
    _tires = List.generate(tireN, (_) => _TireControllers());

    final notes = widget.store.dezentNotes;
    for (var i = 0; i < _rims.length && i < notes.length; i++) {
      final raw = notes[i].trim();
      if (raw.isEmpty) continue;
      final m = RegExp(r'-?\d+').firstMatch(raw);
      if (m != null) {
        _rims[i].et = int.tryParse(m.group(0)!) ?? _rims[i].et;
      }
    }
    for (final r in _rims) {
      r.width = _nearestDouble(kRimWidths, r.width);
      if (!kRimDiameters.contains(r.diameter)) r.diameter = 18;
      if (!kEtValues.contains(r.et)) r.et = 35;
      if (!kPcdBoltCounts.contains(r.pcdBolts)) r.pcdBolts = 5;
      r.pcdDiameter = _nearestDouble(kPcdDiameters, r.pcdDiameter);
      if (r.centerBore != null) {
        r.centerBore = _nearestDouble(kCommonCenterBores, r.centerBore!);
      }
    }
    for (final t in _tires) {
      if (!kTireWidths.contains(t.width)) t.width = 225;
      if (!kTireAspects.contains(t.aspect)) t.aspect = 40;
      if (!kTireDiameters.contains(t.diameter)) t.diameter = 18;
      if (!kTireConstructions.contains(t.construction)) t.construction = 'R';
      if (!kTirePrefixes.contains(t.prefix)) t.prefix = '';
      if (!kTireSuffixes.contains(t.suffix)) t.suffix = '';
      t.treadDepths = [
        for (final v in t.treadDepths) _nearestDouble(_treadValues, v),
      ];
    }

    _loadSavedSpecs();
  }

  Future<void> _loadSavedSpecs() async {
    final saved = await widget.store.loadSpecs();
    if (saved == null || !mounted) return;
    setState(() {
      for (var i = 0; i < _rims.length && i < saved.rims.length; i++) {
        _applyRim(_rims[i], saved.rims[i]);
      }
      for (var i = 0; i < _tires.length && i < saved.tires.length; i++) {
        _applyTire(_tires[i], saved.tires[i]);
      }
      _notesCtrl.text = saved.notes;
    });
  }

  void _applyRim(_RimControllers c, RimSpecs r) {
    if (r.brand.isNotEmpty) c.brand.text = r.brand;

    final pcd = RegExp(r'(\d+)\s*[x×]\s*([\d.]+)', caseSensitive: false)
        .firstMatch(r.pcd);
    if (pcd != null) {
      final bolts = int.tryParse(pcd.group(1)!);
      final dia = double.tryParse(pcd.group(2)!);
      if (bolts != null &&
          dia != null &&
          kPcdBoltCounts.contains(bolts) &&
          kPcdDiameters.contains(dia)) {
        c.pcdBolts = bolts;
        c.pcdDiameter = dia;
        c.pcdManual = null;
      } else if (r.pcd.trim().isNotEmpty) {
        c.pcdManual = r.pcd.trim();
      }
    } else if (r.pcd.trim().isNotEmpty) {
      c.pcdManual = r.pcd.trim();
    }

    final et = RegExp(r'-?\d+').firstMatch(r.et);
    if (et != null) {
      final v = int.tryParse(et.group(0)!);
      if (v != null && kEtValues.contains(v)) c.et = v;
    }

    final size =
        RegExp(r'(\d+(?:[.,]\d+)?)\s*J?\s*[x×]\s*(\d+)', caseSensitive: false)
            .firstMatch(r.size);
    if (size != null) {
      final w = double.tryParse(size.group(1)!.replaceAll(',', '.'));
      final d = int.tryParse(size.group(2)!);
      if (w != null &&
          d != null &&
          kRimWidths.contains(w) &&
          kRimDiameters.contains(d)) {
        c.width = w;
        c.diameter = d;
        c.diameterSet = true;
        c.sizeEtManual = null;
      } else if (r.size.trim().isNotEmpty) {
        c.sizeEtManual = '${r.size.trim()} ${r.et}'.trim();
      }
    } else if (r.size.trim().isNotEmpty) {
      c.sizeEtManual = '${r.size.trim()} ${r.et}'.trim();
    }

    final cbRaw = r.centerBore.trim();
    if (cbRaw.isEmpty) {
      c.centerBore = null;
      c.cbManual = null;
    } else {
      final cb = double.tryParse(cbRaw.replaceAll(',', '.'));
      if (cb != null && kCommonCenterBores.contains(cb)) {
        c.centerBore = cb;
        c.cbManual = null;
      } else if (cb != null) {
        c.centerBore = _nearestDouble(kCommonCenterBores, cb);
        c.cbManual = cbRaw;
      } else {
        c.cbManual = cbRaw;
      }
    }
  }

  void _applyTire(_TireControllers c, TireSpecs t) {
    if (t.brand.isNotEmpty) c.brand.text = t.brand;
    if (t.model.isNotEmpty) c.model.text = t.model;

    final size = tryParseTireSize(t.size);
    if (size != null) {
      c.prefix = size.prefix;
      c.width = size.width;
      c.aspect = size.aspect;
      c.construction = size.construction;
      c.diameter = size.diameter;
      c.suffix = size.suffix;
      c.diameterSet = true;
      c.sizeManual = null;
    } else if (t.size.trim().isNotEmpty) {
      c.sizeManual = t.size.trim();
    }

    final dot = t.dot.replaceAll(RegExp(r'\D'), '');
    if (dot.length == 4) {
      final wk = int.parse(dot.substring(0, 2));
      final yr = int.parse(dot.substring(2));
      if (_dotWeeks.contains(wk) && _dotYears.contains(yr)) {
        c.dotWeek = wk;
        c.dotYear = yr;
        c.dotManual = null;
      } else {
        c.dotManual = dot;
      }
    } else if (dot.isNotEmpty) {
      c.dotManual = dot;
    }

    final treadRaw = t.treadMm.trim();
    final bits = treadRaw
        .split(RegExp(r'\s*[,;/|]\s*'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (bits.length > 1) {
      final vals = <double>[];
      for (final bit in bits) {
        final n = double.tryParse(bit.replaceAll(',', '.'));
        if (n != null) vals.add(_nearestDouble(_treadValues, n));
      }
      if (vals.isNotEmpty) {
        c.treadDepths = vals;
        c.treadManual = null;
      } else {
        c.treadManual = treadRaw;
      }
    } else {
      final tread = double.tryParse(treadRaw.replaceAll(',', '.'));
      if (tread != null) {
        c.treadDepths = [_nearestDouble(_treadValues, tread)];
        c.treadManual = _treadValues.contains(tread) ? null : treadRaw;
      } else if (treadRaw.isNotEmpty) {
        c.treadManual = treadRaw;
      }
    }

    c.season = t.season;
    c.extraLoad = t.extraLoad;
    c.runFlat = t.runFlat;
  }

  static int _nearestInt(List<int> values, int v) {
    var best = values.first;
    for (final x in values) {
      if ((x - v).abs() < (best - v).abs()) best = x;
    }
    return best;
  }

  /// Width changed: pick usual aspect; Ø only if this tire Ø still unset.
  void _onTireWidth(_TireControllers c, int w) {
    c.width = w;
    c.aspect = _nearestInt(kTireAspects, preferredAspectForWidth(w));
    if (!c.diameterSet) {
      c.diameter =
          _nearestInt(kTireDiameters, preferredDiameterFor(w, c.aspect));
    }
  }

  /// Aspect changed: keep width; Ø only if this tire Ø still unset.
  void _onTireAspect(_TireControllers c, int a) {
    c.aspect = a;
    if (!c.diameterSet) {
      c.diameter =
          _nearestInt(kTireDiameters, preferredDiameterFor(c.width, a));
    }
  }

  /// Mark this tire Ø set; copy to unset rims/tires (fitted set = same Ø).
  void _setTireDiameter(_TireControllers c, int d) {
    c.diameter = _nearestInt(kTireDiameters, d);
    c.diameterSet = true;
    _syncUnsetDiameters(c.diameter);
  }

  /// Mark this rim Ø set; copy to unset rims/tires.
  void _setRimDiameter(_RimControllers c, int d) {
    c.diameter = _nearestInt(kRimDiameters, d);
    c.diameterSet = true;
    _syncUnsetDiameters(c.diameter);
  }

  void _syncUnsetDiameters(int d) {
    final rimD = _nearestInt(kRimDiameters, d);
    final tireD = _nearestInt(kTireDiameters, d);
    for (final r in _rims) {
      if (!r.diameterSet) r.diameter = rimD;
    }
    for (final t in _tires) {
      if (!t.diameterSet) t.diameter = tireD;
    }
  }

  static double _nearestDouble(List<double> values, double v) {
    var best = values.first;
    var bestD = (best - v).abs();
    for (final x in values) {
      final d = (x - v).abs();
      if (d < bestD) {
        best = x;
        bestD = d;
      }
    }
    return best;
  }

  @override
  void dispose() {
    for (final r in _rims) {
      r.dispose();
    }
    for (final t in _tires) {
      t.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  VoidCallback? _dup(int index, VoidCallback action) =>
      index > 0 ? action : null;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final specs = SessionSpecs(
        rims: _rims.map((c) => c.toSpecs()).toList(),
        tires: _tires.map((c) => c.toSpecs()).toList(),
        notes: _notesCtrl.text,
      );
      await widget.store.saveSpecs(specs);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DoneScreen(store: widget.store)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skipSpecs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip specs?'),
        content: const Text(
          'Continue without saving the numbers? You can still find the '
          'photos from the home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DoneScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final etOnly = _config?.etOnlyByAxis == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await leaveToHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Specs'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => leaveToHome(context),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _skipSpecs,
              child: const Text('Skip'),
            ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Numbers for the ad',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Roll the dials, or tap the pencil to type freely. '
                  'Back arrow restores dial defaults.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                ),
                if (_rims.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    _rims.length == 1 ? 'Rim' : 'Rims',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  for (var i = 0; i < _rims.length; i++) ...[
                    const SizedBox(height: 16),
                    if (_rims.length > 1)
                      Text(
                        etOnly && i > 0
                            ? 'Rim type ${i + 1} — ET only'
                            : 'Rim type ${i + 1}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    if (_rims.length > 1) const SizedBox(height: 10),
                    _rimFields(i, face: !(etOnly && i > 0)),
                  ],
                ],
                if (_tires.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    _tires.length == 1 ? 'Tire' : 'Tires',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  for (var i = 0; i < _tires.length; i++) ...[
                    const SizedBox(height: 16),
                    if (_tires.length > 1)
                      Text(
                        'Tire type ${i + 1}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    if (_tires.length > 1) const SizedBox(height: 10),
                    _tireFields(i),
                  ],
                ],
                const SizedBox(height: 28),
                Text(
                  'Notes (optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. curb rash on one spoke, no TPMS…',
                    filled: true,
                    fillColor: const Color(0xFF1C1F28),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save specs'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saved as specs.txt next to the photos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rimFields(int i, {required bool face}) {
    final c = _rims[i];
    final prev = i > 0 ? _rims[i - 1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (face) ...[
          SuggestField(
            controller: c.brand,
            label: 'Rim brand',
            hint: 'e.g. Volkswagen / Ronal',
            options: kRimBrands,
            onDuplicate: _dup(i, () {
              c.brand.text = prev!.brand.text;
              setState(() {});
            }),
          ),
          const SizedBox(height: 12),
          PcdSelector(
            bolts: c.pcdBolts,
            diameter: c.pcdDiameter,
            onBoltsChanged: (b) => setState(() => c.pcdBolts = b),
            onDiameterChanged: (d) => setState(() => c.pcdDiameter = d),
            onResetToDefaults: () => setState(c.resetPcdDefaults),
            onManualChanged: (v) => setState(() => c.pcdManual = v),
            onDuplicate: _dup(i, () {
              setState(() {
                c.pcdBolts = prev!.pcdBolts;
                c.pcdDiameter = prev.pcdDiameter;
                c.pcdManual = prev.pcdManual;
              });
            }),
          ),
          const SizedBox(height: 12),
          RimSizeSelector(
            width: c.width,
            diameter: c.diameter,
            et: c.et,
            centerBore: c.centerBore,
            onWidthChanged: (w) => setState(() => c.width = w),
            onDiameterChanged: (d) => setState(() => _setRimDiameter(c, d)),
            onEtChanged: (e) => setState(() => c.et = e),
            onCenterBoreChanged: (v) => setState(() => c.centerBore = v),
            onResetToDefaults: () => setState(c.resetSizeEtDefaults),
            onManualChanged: (v) => setState(() => c.sizeEtManual = v),
            onDuplicate: _dup(i, () {
              setState(() {
                c.width = prev!.width;
                c.diameter = prev.diameter;
                c.et = prev.et;
                c.centerBore = prev.centerBore;
                c.sizeEtManual = prev.sizeEtManual;
                c.cbManual = prev.cbManual;
                c.diameterSet = prev.diameterSet;
              });
            }),
          ),
          const SizedBox(height: 12),
        ] else ...[
          EtSelector(
            et: c.et,
            onChanged: (e) => setState(() => c.et = e),
            onResetToDefaults: () => setState(() {
              c.et = 35;
              c.sizeEtManual = null;
            }),
            onManualChanged: (v) => setState(() => c.sizeEtManual = v),
            onDuplicate: _dup(i, () => setState(() => c.et = prev!.et)),
          ),
        ],
      ],
    );
  }

  Widget _tireFields(int i) {
    final c = _tires[i];
    final prev = i > 0 ? _tires[i - 1] : null;
    final models = modelsForBrand(c.brand.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuggestField(
          controller: c.brand,
          label: 'Tire brand',
          hint: 'e.g. Michelin',
          options: kTireBrands,
          onChanged: (_) => setState(() {}),
          onDuplicate: _dup(i, () {
            c.brand.text = prev!.brand.text;
            setState(() {});
          }),
        ),
        const SizedBox(height: 12),
        SuggestField(
          controller: c.model,
          label: 'Tire model',
          hint: models.isEmpty ? 'e.g. Pilot Sport 4' : 'Pick or type',
          options: models,
          onDuplicate: _dup(i, () {
            c.model.text = prev!.model.text;
            setState(() {});
          }),
        ),
        const SizedBox(height: 12),
        TireSizeSelector(
          prefix: c.prefix,
          width: c.width,
          aspect: c.aspect,
          construction: c.construction,
          diameter: c.diameter,
          suffix: c.suffix,
          onPrefixChanged: (p) => setState(() => c.prefix = p),
          onWidthChanged: (w) => setState(() => _onTireWidth(c, w)),
          onAspectChanged: (a) => setState(() => _onTireAspect(c, a)),
          onConstructionChanged: (k) => setState(() => c.construction = k),
          onDiameterChanged: (d) => setState(() => _setTireDiameter(c, d)),
          onSuffixChanged: (s) => setState(() => c.suffix = s),
          onResetToDefaults: () => setState(c.resetSizeDefaults),
          onManualChanged: (v) => setState(() => c.sizeManual = v),
          onDuplicate: _dup(i, () {
            setState(() {
              c.prefix = prev!.prefix;
              c.width = prev.width;
              c.aspect = prev.aspect;
              c.construction = prev.construction;
              c.diameter = prev.diameter;
              c.suffix = prev.suffix;
              c.sizeManual = prev.sizeManual;
              c.diameterSet = prev.diameterSet;
            });
          }),
        ),
        const SizedBox(height: 12),
        DialStrip(
          label: 'DOT (week / year)',
          manualHint: 'e.g. 3412',
          dialText: () => c.dotLabel,
          onResetToDefaults: () => setState(c.resetDotDefaults),
          onManualChanged: (v) => setState(() => c.dotManual = v),
          onDuplicate: _dup(i, () {
            setState(() {
              c.dotWeek = prev!.dotWeek;
              c.dotYear = prev.dotYear;
              c.dotManual = prev.dotManual;
            });
          }),
          children: [
            InlineDial<int>(
              values: _dotWeeks,
              value: c.dotWeek,
              width: 56,
              labelOf: (w) => w.toString().padLeft(2, '0'),
              onChanged: (w) => setState(() => c.dotWeek = w),
            ),
            const DialSep('/'),
            InlineDial<int>(
              values: _dotYears,
              value: c.dotYear,
              width: 56,
              labelOf: (y) => y.toString().padLeft(2, '0'),
              onChanged: (y) => setState(() => c.dotYear = y),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DialStrip(
          label: 'Tread depth (mm)',
          manualHint: 'e.g. 6.0, 4.5',
          dialText: () => c.treadDepths.map(_fmtTread).join(', '),
          onResetToDefaults: () => setState(() {
            c.resetTreadDefaults();
          }),
          onManualChanged: (v) => setState(() => c.treadManual = v),
          onDuplicate: _dup(i, () {
            setState(() {
              c.treadDepths = List.of(prev!.treadDepths);
              c.treadManual = prev.treadManual;
            });
          }),
          children: [
            for (var d = 0; d < c.treadDepths.length; d++) ...[
              if (d > 0) const DialGap(),
              InlineDial<double>(
                values: _treadValues,
                value: c.treadDepths[d],
                width: 64,
                labelOf: _fmtTread,
                onChanged: (v) => setState(() {
                  c.treadDepths[d] = v;
                  c.treadManual = null;
                }),
              ),
            ],
            IconButton(
              tooltip: 'Add tread depth',
              onPressed: () => setState(() {
                c.treadDepths.add(c.treadDepths.last);
                c.treadManual = null;
              }),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Season',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
            if (i > 0)
              IconButton.filledTonal(
                tooltip: 'Copy season from previous type',
                onPressed: () => setState(() => c.season = prev!.season),
                icon: const Icon(Icons.copy_all_outlined),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final opt in const [
              ('', '—'),
              ('letni', 'Letní'),
              ('zimni', 'Zimní'),
              ('celorocni', 'Celoroční'),
            ])
              ChoiceChip(
                label: Text(opt.$2),
                selected: c.season == opt.$1,
                onSelected: (_) => setState(() => c.season = opt.$1),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('EXTRA LOAD'),
              selected: c.extraLoad,
              onSelected: (v) => setState(() => c.extraLoad = v),
            ),
            FilterChip(
              label: const Text('RUNFLAT'),
              selected: c.runFlat,
              onSelected: (v) => setState(() => c.runFlat = v),
            ),
            if (i > 0)
              ActionChip(
                avatar: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy from previous'),
                onPressed: () => setState(() {
                  c.extraLoad = prev!.extraLoad;
                  c.runFlat = prev.runFlat;
                }),
              ),
          ],
        ),
      ],
    );
  }

  static String _fmtTread(double v) => v.toStringAsFixed(1);
}

class _RimControllers {
  final brand = TextEditingController();
  int pcdBolts = 5;
  double pcdDiameter = 112;
  double width = 7.5;
  int diameter = 18;
  int et = 35;
  double? centerBore = 57.1;

  String? pcdManual;
  String? sizeEtManual;
  String? cbManual;

  String get sizeLabel => formatRimSize(width, diameter);

  void resetPcdDefaults() {
    pcdBolts = 5;
    pcdDiameter = 112;
    pcdManual = null;
  }

  bool diameterSet = false;

  void resetSizeEtDefaults() {
    width = 7.5;
    diameter = 18;
    et = 35;
    centerBore = 57.1;
    sizeEtManual = null;
    cbManual = null;
    diameterSet = false;
  }

  RimSpecs toSpecs() {
    var pcd = pcdManual?.trim();
    if (pcd == null || pcd.isEmpty) {
      pcd = formatPcd(pcdBolts, pcdDiameter);
    }

    var size = sizeLabel;
    var etStr = 'ET$et';
    var sizeMan = sizeEtManual?.trim();
    String? cbFromLine;
    if (sizeMan != null && sizeMan.isNotEmpty) {
      final cbMatch =
          RegExp(r'CB\s*([\d.,]+)', caseSensitive: false).firstMatch(sizeMan);
      if (cbMatch != null) {
        cbFromLine = cbMatch.group(1)!.replaceAll(',', '.');
        sizeMan = sizeMan.replaceFirst(cbMatch.group(0)!, '').trim();
      }
      final etMatch =
          RegExp(r'ET\s*(-?\d+)', caseSensitive: false).firstMatch(sizeMan);
      if (etMatch != null) {
        etStr = 'ET${etMatch.group(1)}';
        size = sizeMan.replaceFirst(etMatch.group(0)!, '').trim();
        if (size.isEmpty) size = sizeLabel;
      } else if (RegExp(r'^-?\d+$').hasMatch(sizeMan)) {
        etStr = 'ET$sizeMan';
      } else {
        size = sizeMan;
      }
    }

    var cb = '';
    final cbMan = cbManual?.trim();
    if (cbFromLine != null && cbFromLine.isNotEmpty) {
      cb = cbFromLine;
    } else if (cbMan != null && cbMan.isNotEmpty) {
      cb = cbMan;
    } else if (sizeMan != null && sizeMan.isNotEmpty) {
      cb = '';
    } else if (centerBore != null) {
      cb = formatCb(centerBore!);
    }

    return RimSpecs(
      brand: brand.text,
      pcd: pcd,
      et: etStr,
      size: size,
      centerBore: cb,
    );
  }

  void dispose() {
    brand.dispose();
  }
}

class _TireControllers {
  final brand = TextEditingController();
  final model = TextEditingController();
  String prefix = '';
  int width = 225;
  int aspect = 40;
  String construction = 'R';
  int diameter = 18;
  String suffix = '';
  int dotWeek = 1;
  int dotYear = 23;
  List<double> treadDepths = [3.0];
  String season = '';
  bool extraLoad = false;
  bool runFlat = false;

  String? sizeManual;
  String? dotManual;
  String? treadManual;

  String get sizeLabel => formatTireSize(
        prefix: prefix,
        width: width,
        aspect: aspect,
        construction: construction,
        diameter: diameter,
        suffix: suffix,
      );

  String get dotLabel =>
      '${dotWeek.toString().padLeft(2, '0')}${dotYear.toString().padLeft(2, '0')}';

  bool diameterSet = false;

  void resetSizeDefaults() {
    prefix = '';
    width = 225;
    aspect = 40;
    construction = 'R';
    diameter = 18;
    suffix = '';
    sizeManual = null;
    diameterSet = false;
  }

  void resetDotDefaults() {
    dotWeek = 1;
    dotYear = 23;
    dotManual = null;
  }

  void resetTreadDefaults() {
    treadDepths = [3.0];
    treadManual = null;
  }

  TireSpecs toSpecs() {
    final size = (sizeManual != null && sizeManual!.trim().isNotEmpty)
        ? sizeManual!.trim()
        : sizeLabel;
    final dot = (dotManual != null && dotManual!.trim().isNotEmpty)
        ? dotManual!.trim().replaceAll(RegExp(r'\D'), '')
        : dotLabel;
    final tread = (treadManual != null && treadManual!.trim().isNotEmpty)
        ? treadManual!.trim()
        : treadDepths.map((v) => v.toStringAsFixed(1)).join(', ');

    return TireSpecs(
      brand: brand.text,
      model: model.text,
      size: size,
      dot: dot,
      treadMm: tread,
      season: season,
      extraLoad: extraLoad,
      runFlat: runFlat,
    );
  }

  void dispose() {
    brand.dispose();
    model.dispose();
  }
}

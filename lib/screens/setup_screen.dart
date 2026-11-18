import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/shoot_plan.dart';
import '../services/session_store.dart';
import 'wizard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.category});

  final ShootCategory category;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameCtrl = TextEditingController();
  final List<TextEditingController> _dezentCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  int _pieces = 4;
  int _tireTypes = 1;
  int _rimTypes = 1;
  bool _rimsDifferByAxis = false;
  bool _etOnlyByAxis = false;
  bool _spareHasRim = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _dezentCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  ShootConfig get _config => ShootConfig(
        pieceCount: _pieces,
        tireTypes: _tireTypes,
        rimTypes: _rimTypes,
        rimsDifferByAxis: _rimsDifferByAxis,
        etOnlyByAxis: _etOnlyByAxis,
      ).forCategory(widget.category);

  void _setPieces(int n) {
    setState(() {
      _pieces = n;
      if (_tireTypes > n) _tireTypes = n;
      if (_rimTypes > n) _rimTypes = n;
      if (_rimTypes < 2) {
        _rimsDifferByAxis = false;
        _etOnlyByAxis = false;
      }
    });
  }

  void _applyPreset(ShootConfig preset) {
    setState(() {
      _pieces = preset.pieceCount;
      _tireTypes = preset.tireTypes;
      _rimTypes = preset.rimTypes;
      _rimsDifferByAxis = preset.rimsDifferByAxis;
      _etOnlyByAxis = preset.etOnlyByAxis;
    });
  }

  Future<void> _start() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this shoot a short name')),
      );
      return;
    }

    final cfg = _config;
    setState(() => _busy = true);
    try {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
        return;
      }
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();

      final etNotes = [
        for (var i = 0; i < cfg.rimTypes; i++) _dezentCtrls[i].text.trim(),
      ];

      final store = await SessionStore.create(
        name: name,
        category: widget.category,
        config: widget.category.usesShootConfig ? cfg : null,
        dezentNotes: etNotes.where((e) => e.isNotEmpty).toList(),
        spareHasRim: _spareHasRim,
      );

      final steps = buildWizard(
        category: widget.category,
        config: cfg,
        spareHasRim: _spareHasRim,
        etNotes: etNotes,
      );

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WizardScreen(store: store, steps: steps),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final cfg = _config;

    return Scaffold(
      appBar: AppBar(title: Text(cat.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Session name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'e.g. civic_fk8_michelin_18',
                filled: true,
                fillColor: const Color(0xFF1C1F28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos go to Documents/WheelShot/<name>/',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            if (cat.usesShootConfig) ...[
              const SizedBox(height: 28),
              _sectionTitle('Pieces'),
              const SizedBox(height: 4),
              Text(
                'How many physical wheels/tires/rims in this listing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              const SizedBox(height: 12),
              _countChips(
                max: 4,
                selected: _pieces,
                onSelected: _setPieces,
              ),
              if (cat.includesTire) ...[
                const SizedBox(height: 24),
                _sectionTitle('Tire types'),
                const SizedBox(height: 4),
                Text(
                  'How many distinct tires to shoot (same = once).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 12),
                _countChips(
                  max: _pieces,
                  selected: _tireTypes.clamp(1, _pieces),
                  onSelected: (n) => setState(() => _tireTypes = n),
                ),
              ],
              if (cat.includesRim) ...[
                const SizedBox(height: 24),
                _sectionTitle('Rim types'),
                const SizedBox(height: 4),
                Text(
                  'How many distinct rims to shoot (same = once).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 12),
                _countChips(
                  max: _pieces,
                  selected: _rimTypes.clamp(1, _pieces),
                  onSelected: (n) => setState(() {
                    _rimTypes = n;
                    if (n < 2) {
                      _rimsDifferByAxis = false;
                      _etOnlyByAxis = false;
                    }
                  }),
                ),
                if (_rimTypes > 1) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rims differ by axis'),
                    subtitle: const Text(
                      'Front/rear (or similar) differ in width and/or ET',
                    ),
                    value: _rimsDifferByAxis || _etOnlyByAxis,
                    onChanged: (v) => setState(() {
                      _rimsDifferByAxis = v;
                      if (!v) _etOnlyByAxis = false;
                    }),
                  ),
                  if (_rimsDifferByAxis || _etOnlyByAxis)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Same rim face — only ET differs'),
                      subtitle: const Text(
                        'Shared brand/size photos; ET shot per type (old 4-2)',
                      ),
                      value: _etOnlyByAxis,
                      onChanged: (v) => setState(() {
                        _etOnlyByAxis = v;
                        if (v) _rimsDifferByAxis = true;
                      }),
                    ),
                ],
              ],
              const SizedBox(height: 16),
              Text(
                cfg.mixNote,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'Quick presets',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('4'),
                    onPressed: () => _applyPreset(ShootConfig.preset4()),
                  ),
                  ActionChip(
                    label: const Text('2+2'),
                    onPressed: () => _applyPreset(ShootConfig.preset2plus2()),
                  ),
                  ActionChip(
                    label: const Text('3+1'),
                    onPressed: () => _applyPreset(ShootConfig.preset3plus1()),
                  ),
                  if (cat.includesRim)
                    ActionChip(
                      label: const Text('4-2 ET'),
                      onPressed: () =>
                          _applyPreset(ShootConfig.preset4minus2()),
                    ),
                ],
              ),
              if (cfg.needsSetupEtHints) ...[
                const SizedBox(height: 24),
                _sectionTitle('ET per rim type (optional)'),
                const SizedBox(height: 4),
                Text(
                  'Hints for the ET photo steps — can also be filled later from stamps.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < cfg.rimTypes; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  TextField(
                    controller: _dezentCtrls[i],
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9ETKetk+\-., ]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Rim type ${i + 1} ET',
                      hintText: 'e.g. ET35',
                      filled: true,
                      fillColor: const Color(0xFF1C1F28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ],
            if (cat == ShootCategory.spare) ...[
              const SizedBox(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Spare is mounted on a rim'),
                subtitle: const Text('Also capture brand / size / ET'),
                value: _spareHasRim,
                onChanged: (v) => setState(() => _spareHasRim = v),
              ),
            ],
            const SizedBox(height: 36),
            FilledButton(
              onPressed: _busy ? null : _start,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start wizard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );

  Widget _countChips({
    required int max,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var n = 1; n <= max; n++)
          ChoiceChip(
            label: Text('$n'),
            selected: selected == n,
            onSelected: (_) => onSelected(n),
          ),
      ],
    );
  }
}

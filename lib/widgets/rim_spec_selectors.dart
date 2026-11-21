import 'package:flutter/material.dart';

import '../data/rim_catalog.dart';
import 'inline_dial.dart';

class PcdSelector extends StatelessWidget {
  const PcdSelector({
    super.key,
    required this.bolts,
    required this.diameter,
    required this.onBoltsChanged,
    required this.onDiameterChanged,
    required this.onResetToDefaults,
    required this.onManualChanged,
    this.onDuplicate,
    this.reportLive = false,
  });

  final int bolts;
  final double diameter;
  final ValueChanged<int> onBoltsChanged;
  final ValueChanged<double> onDiameterChanged;
  final VoidCallback onResetToDefaults;
  final ValueChanged<String?> onManualChanged;
  final VoidCallback? onDuplicate;
  final bool reportLive;

  @override
  Widget build(BuildContext context) {
    return DialStrip(
      label: 'PCD / rozteč',
      manualHint: 'e.g. 5x112',
      dialText: () => formatPcd(bolts, diameter),
      onResetToDefaults: onResetToDefaults,
      onManualChanged: onManualChanged,
      onDuplicate: onDuplicate,
      children: [
        InlineDial<int>(
          values: kPcdBoltCounts,
          value: bolts,
          width: 52,
          labelOf: (b) => '$b',
          onChanged: onBoltsChanged,
          reportLive: reportLive,
        ),
        const DialSep('x'),
        InlineDial<double>(
          values: kPcdDiameters,
          value: diameter,
          width: 80,
          labelOf: _fmtMm,
          onChanged: onDiameterChanged,
          reportLive: reportLive,
        ),
      ],
    );
  }
}

class RimSizeSelector extends StatelessWidget {
  const RimSizeSelector({
    super.key,
    required this.width,
    required this.diameter,
    required this.et,
    required this.centerBore,
    required this.onWidthChanged,
    required this.onDiameterChanged,
    required this.onEtChanged,
    required this.onCenterBoreChanged,
    required this.onResetToDefaults,
    required this.onManualChanged,
    this.onDuplicate,
  });

  final double width;
  final int diameter;
  final int et;
  final double? centerBore;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<int> onDiameterChanged;
  final ValueChanged<int> onEtChanged;
  final ValueChanged<double?> onCenterBoreChanged;
  final VoidCallback onResetToDefaults;
  final ValueChanged<String?> onManualChanged;
  final VoidCallback? onDuplicate;

  static final _bores = <double?>[null, ...kCommonCenterBores];

  @override
  Widget build(BuildContext context) {
    return DialStrip(
      label: 'Rim size + ET',
      manualHint: 'e.g. 7.5Jx17 ET47 CB57.1',
      dialText: () => formatRimSizeLine(
        width: width,
        diameter: diameter,
        et: et,
        centerBore: centerBore,
      ),
      onResetToDefaults: onResetToDefaults,
      onManualChanged: onManualChanged,
      onDuplicate: onDuplicate,
      children: [
        InlineDial<double>(
          values: kRimWidths,
          value: width,
          width: 46,
          labelOf: _fmtWidth,
          onChanged: onWidthChanged,
        ),
        const DialSep('Jx'),
        InlineDial<int>(
          values: kRimDiameters,
          value: diameter,
          width: 40,
          labelOf: (d) => '$d',
          onChanged: onDiameterChanged,
        ),
        const DialSep('ET'),
        InlineDial<int>(
          values: kEtValues,
          value: et,
          width: 42,
          labelOf: (e) => '$e',
          onChanged: onEtChanged,
        ),
        const DialSep('CB'),
        InlineDial<double?>(
          values: _bores,
          value: centerBore,
          width: 56,
          labelOf: (v) => v == null ? '—' : _fmtMm(v),
          onChanged: onCenterBoreChanged,
        ),
      ],
    );
  }
}

class EtSelector extends StatelessWidget {
  const EtSelector({
    super.key,
    required this.et,
    required this.onChanged,
    required this.onResetToDefaults,
    required this.onManualChanged,
    this.onDuplicate,
    this.reportLive = false,
  });

  final int et;
  final ValueChanged<int> onChanged;
  final VoidCallback onResetToDefaults;
  final ValueChanged<String?> onManualChanged;
  final VoidCallback? onDuplicate;
  final bool reportLive;

  @override
  Widget build(BuildContext context) {
    return DialStrip(
      label: 'ET',
      manualHint: 'e.g. 35',
      dialText: () => '$et',
      onResetToDefaults: onResetToDefaults,
      onManualChanged: onManualChanged,
      onDuplicate: onDuplicate,
      children: [
        const DialSep('ET'),
        InlineDial<int>(
          values: kEtValues,
          value: et,
          width: 72,
          labelOf: (e) => '$e',
          onChanged: onChanged,
          reportLive: reportLive,
        ),
      ],
    );
  }
}

String formatRimSize(double width, int diameter) =>
    width == width.roundToDouble()
        ? '${width.toInt()}Jx$diameter'
        : '${width}Jx$diameter';

String formatRimSizeLine({
  required double width,
  required int diameter,
  required int et,
  required double? centerBore,
}) {
  final size = formatRimSize(width, diameter);
  if (centerBore == null) return '$size ET$et';
  return '$size ET$et CB${_fmtMm(centerBore)}';
}

String _fmtWidth(double w) => w == w.roundToDouble() ? '${w.toInt()}' : '$w';

String formatCb(double d) => _fmtMm(d);

String _fmtMm(double d) => d == d.roundToDouble()
    ? d.toInt().toString()
    : ((d * 100).round() % 10 == 0
        ? d.toStringAsFixed(1)
        : d.toStringAsFixed(2));

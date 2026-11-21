import 'package:flutter/material.dart';

import '../data/tire_size.dart';
import 'inline_dial.dart';

/// Tire sidewall dials: prefix, width, aspect, construction, diameter, suffix.
class TireSizeSelector extends StatelessWidget {
  const TireSizeSelector({
    super.key,
    required this.prefix,
    required this.width,
    required this.aspect,
    required this.construction,
    required this.diameter,
    required this.suffix,
    required this.onPrefixChanged,
    required this.onWidthChanged,
    required this.onAspectChanged,
    required this.onConstructionChanged,
    required this.onDiameterChanged,
    required this.onSuffixChanged,
    required this.onResetToDefaults,
    required this.onManualChanged,
    this.onDuplicate,
    this.reportLive = false,
  });

  final String prefix;
  final int width;
  final int aspect;
  final String construction;
  final int diameter;
  final String suffix;
  final ValueChanged<String> onPrefixChanged;
  final ValueChanged<int> onWidthChanged;
  final ValueChanged<int> onAspectChanged;
  final ValueChanged<String> onConstructionChanged;
  final ValueChanged<int> onDiameterChanged;
  final ValueChanged<String> onSuffixChanged;
  final VoidCallback onResetToDefaults;
  final ValueChanged<String?> onManualChanged;
  final VoidCallback? onDuplicate;
  final bool reportLive;

  @override
  Widget build(BuildContext context) {
    final label = formatTireSize(
      prefix: prefix,
      width: width,
      aspect: aspect,
      construction: construction,
      diameter: diameter,
      suffix: suffix,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DialStrip(
          label: 'Tire size',
          manualHint: 'e.g. T125/80 D16 or 215/65 R16C',
          dialText: () => label,
          onResetToDefaults: onResetToDefaults,
          onManualChanged: onManualChanged,
          onDuplicate: onDuplicate,
          children: [
            InlineDial<String>(
              values: kTirePrefixes,
              value: prefix,
              width: 48,
              labelOf: (p) => p.isEmpty ? '–' : p,
              onChanged: onPrefixChanged,
              reportLive: reportLive,
            ),
            InlineDial<int>(
              values: kTireWidths,
              value: width,
              width: 52,
              labelOf: (w) => '$w',
              onChanged: onWidthChanged,
              reportLive: reportLive,
            ),
            const DialSep('/'),
            InlineDial<int>(
              values: kTireAspects,
              value: aspect,
              width: 44,
              labelOf: (a) => '$a',
              onChanged: onAspectChanged,
              reportLive: reportLive,
            ),
            InlineDial<String>(
              values: kTireConstructions,
              value: construction,
              width: 42,
              labelOf: (k) => k,
              onChanged: onConstructionChanged,
              reportLive: reportLive,
            ),
            InlineDial<int>(
              values: kTireDiameters,
              value: diameter,
              width: 44,
              labelOf: (d) => '$d',
              onChanged: onDiameterChanged,
              reportLive: reportLive,
            ),
            InlineDial<String>(
              values: kTireSuffixes,
              value: suffix,
              width: 48,
              labelOf: (s) => s.isEmpty ? '–' : s,
              onChanged: onSuffixChanged,
              reportLive: reportLive,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tireSizeNote(prefix, suffix),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }
}

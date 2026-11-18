/// Common passenger / light-commercial / spare size combos (EU used market).
/// Cascade: width → aspect → diameter (each step keeps left dials).
library;

class TireSizeCombo {
  const TireSizeCombo(this.width, this.aspect, this.diameter);
  final int width;
  final int aspect;
  final int diameter;
}

/// Frequency-weighted-ish list — first match wins as “expected”.
const List<TireSizeCombo> kTireSizeCombos = [
  // Compact spares
  TireSizeCombo(125, 70, 15),
  TireSizeCombo(125, 80, 15),
  TireSizeCombo(125, 80, 16),
  TireSizeCombo(125, 85, 16),
  TireSizeCombo(125, 90, 16),
  TireSizeCombo(135, 70, 15),
  TireSizeCombo(135, 80, 15),
  TireSizeCombo(135, 80, 16),
  TireSizeCombo(135, 90, 17),
  TireSizeCombo(145, 70, 17),
  TireSizeCombo(145, 80, 18),
  // Common passenger
  TireSizeCombo(155, 65, 14),
  TireSizeCombo(155, 70, 13),
  TireSizeCombo(165, 65, 14),
  TireSizeCombo(165, 70, 14),
  TireSizeCombo(175, 65, 14),
  TireSizeCombo(175, 65, 15),
  TireSizeCombo(175, 70, 13),
  TireSizeCombo(185, 55, 15),
  TireSizeCombo(185, 60, 14),
  TireSizeCombo(185, 60, 15),
  TireSizeCombo(185, 65, 15),
  TireSizeCombo(195, 45, 16),
  TireSizeCombo(195, 50, 15),
  TireSizeCombo(195, 50, 16),
  TireSizeCombo(195, 55, 15),
  TireSizeCombo(195, 55, 16),
  TireSizeCombo(195, 60, 15),
  TireSizeCombo(195, 65, 15),
  TireSizeCombo(205, 40, 17),
  TireSizeCombo(205, 45, 16),
  TireSizeCombo(205, 45, 17),
  TireSizeCombo(205, 50, 16),
  TireSizeCombo(205, 50, 17),
  TireSizeCombo(205, 55, 16),
  TireSizeCombo(205, 55, 17),
  TireSizeCombo(205, 60, 16),
  TireSizeCombo(205, 65, 15),
  TireSizeCombo(205, 65, 16),
  TireSizeCombo(215, 40, 17),
  TireSizeCombo(215, 40, 18),
  TireSizeCombo(215, 45, 16),
  TireSizeCombo(215, 45, 17),
  TireSizeCombo(215, 50, 17),
  TireSizeCombo(215, 55, 16),
  TireSizeCombo(215, 55, 17),
  TireSizeCombo(215, 60, 16),
  TireSizeCombo(215, 60, 17),
  TireSizeCombo(215, 65, 16),
  TireSizeCombo(215, 65, 17),
  TireSizeCombo(225, 35, 19),
  TireSizeCombo(225, 40, 18),
  TireSizeCombo(225, 40, 19),
  TireSizeCombo(225, 45, 17),
  TireSizeCombo(225, 45, 18),
  TireSizeCombo(225, 50, 17),
  TireSizeCombo(225, 50, 18),
  TireSizeCombo(225, 55, 17),
  TireSizeCombo(225, 55, 18),
  TireSizeCombo(225, 60, 17),
  TireSizeCombo(225, 60, 18),
  TireSizeCombo(225, 65, 17),
  TireSizeCombo(235, 35, 19),
  TireSizeCombo(235, 40, 18),
  TireSizeCombo(235, 40, 19),
  TireSizeCombo(235, 45, 17),
  TireSizeCombo(235, 45, 18),
  TireSizeCombo(235, 50, 18),
  TireSizeCombo(235, 55, 17),
  TireSizeCombo(235, 55, 18),
  TireSizeCombo(235, 55, 19),
  TireSizeCombo(235, 60, 18),
  TireSizeCombo(235, 65, 17),
  TireSizeCombo(245, 35, 19),
  TireSizeCombo(245, 35, 20),
  TireSizeCombo(245, 40, 18),
  TireSizeCombo(245, 40, 19),
  TireSizeCombo(245, 45, 18),
  TireSizeCombo(245, 45, 19),
  TireSizeCombo(245, 50, 18),
  TireSizeCombo(255, 35, 19),
  TireSizeCombo(255, 35, 20),
  TireSizeCombo(255, 40, 19),
  TireSizeCombo(255, 45, 18),
  TireSizeCombo(255, 45, 19),
  TireSizeCombo(255, 50, 19),
  TireSizeCombo(255, 55, 18),
  TireSizeCombo(265, 35, 20),
  TireSizeCombo(265, 40, 20),
  TireSizeCombo(265, 45, 20),
  TireSizeCombo(265, 50, 19),
  TireSizeCombo(275, 30, 20),
  TireSizeCombo(275, 35, 19),
  TireSizeCombo(275, 40, 19),
  TireSizeCombo(275, 40, 20),
  TireSizeCombo(275, 45, 20),
  // C / van-ish widths also appear as 205/65R16C etc. — use same dials
  TireSizeCombo(205, 65, 16),
  TireSizeCombo(215, 65, 16),
  TireSizeCombo(225, 70, 15),
  TireSizeCombo(235, 65, 16),
];

int preferredAspectForWidth(int width) {
  for (final c in kTireSizeCombos) {
    if (c.width == width) return c.aspect;
  }
  // fallback: mid profile
  return 55;
}

int preferredDiameterFor(int width, int aspect) {
  for (final c in kTireSizeCombos) {
    if (c.width == width && c.aspect == aspect) return c.diameter;
  }
  for (final c in kTireSizeCombos) {
    if (c.width == width) return c.diameter;
  }
  return 16;
}

List<int> aspectsForWidth(int width, List<int> allAspects) {
  final preferred = <int>[];
  for (final c in kTireSizeCombos) {
    if (c.width == width && !preferred.contains(c.aspect)) {
      preferred.add(c.aspect);
    }
  }
  if (preferred.isEmpty) return allAspects;
  // preferred first, then rest
  final rest = allAspects.where((a) => !preferred.contains(a));
  return [...preferred, ...rest];
}

List<int> diametersFor(int width, int aspect, List<int> allDiameters) {
  final preferred = <int>[];
  for (final c in kTireSizeCombos) {
    if (c.width == width && c.aspect == aspect && !preferred.contains(c.diameter)) {
      preferred.add(c.diameter);
    }
  }
  if (preferred.isEmpty) {
    for (final c in kTireSizeCombos) {
      if (c.width == width && !preferred.contains(c.diameter)) {
        preferred.add(c.diameter);
      }
    }
  }
  if (preferred.isEmpty) return allDiameters;
  final rest = allDiameters.where((d) => !preferred.contains(d));
  return [...preferred, ...rest];
}

/// Sidewall size: prefix, section, aspect, construction, rim, suffix.
///
/// Prefix sits on the width (`T125`, `LT245`, `P225`, `ST205`).
/// Suffix sits on the rim diameter (`16C` van, `16CP` caravan).
library;

const List<String> kTirePrefixes = ['', 'P', 'LT', 'T', 'ST'];
const List<String> kTireSuffixes = ['', 'C', 'CP'];
const List<String> kTireConstructions = ['R', 'ZR', 'B', 'D'];

final List<int> kTireWidths = [for (var w = 125; w <= 335; w += 5) w];
final List<int> kTireAspects = [for (var a = 25; a <= 100; a += 5) a];
final List<int> kTireDiameters = [for (var d = 13; d <= 23; d++) d];

const Map<String, String> kTirePrefixMeaning = {
  'P': 'P-metric passenger',
  'LT': 'light truck',
  'T': 'temporary spare',
  'ST': 'special trailer',
};

const Map<String, String> kTireSuffixMeaning = {
  'C': 'commercial / van',
  'CP': 'caravan',
};

class TireSizeParts {
  const TireSizeParts({
    required this.prefix,
    required this.width,
    required this.aspect,
    required this.construction,
    required this.diameter,
    required this.suffix,
  });

  final String prefix;
  final int width;
  final int aspect;
  final String construction;
  final int diameter;
  final String suffix;
}

String formatTireSize({
  required String prefix,
  required int width,
  required int aspect,
  required String construction,
  required int diameter,
  required String suffix,
}) =>
    '$prefix$width/$aspect $construction$diameter$suffix';

/// One line under the dials. Blank prefix/suffix still names the odd letters.
String tireSizeNote(String prefix, String suffix) {
  final bits = <String>[];
  final p = kTirePrefixMeaning[prefix];
  final s = kTireSuffixMeaning[suffix];
  if (p != null) bits.add('$prefix $p');
  if (s != null) bits.add('$suffix $s');
  if (bits.isEmpty) {
    return 'Prefix T spare. Suffix C van, CP caravan.';
  }
  return bits.join(' · ');
}

final _sizePattern = RegExp(
  r'(LT|ST|P|T)?(\d{3})/(\d{2,3})\s*(ZR|R|B|D)?\s*(\d{2})\s*(CP|C)?',
  caseSensitive: false,
);

/// Null when the string is not a dial size (caller keeps free text).
TireSizeParts? tryParseTireSize(String raw) {
  final m = _sizePattern.firstMatch(raw.trim());
  if (m == null) return null;
  final prefix = (m.group(1) ?? '').toUpperCase();
  final width = int.parse(m.group(2)!);
  final aspect = int.parse(m.group(3)!);
  final construction = (m.group(4) ?? 'R').toUpperCase();
  final diameter = int.parse(m.group(5)!);
  final suffix = (m.group(6) ?? '').toUpperCase();
  if (!kTirePrefixes.contains(prefix) ||
      !kTireWidths.contains(width) ||
      !kTireAspects.contains(aspect) ||
      !kTireConstructions.contains(construction) ||
      !kTireDiameters.contains(diameter) ||
      !kTireSuffixes.contains(suffix)) {
    return null;
  }
  return TireSizeParts(
    prefix: prefix,
    width: width,
    aspect: aspect,
    construction: construction,
    diameter: diameter,
    suffix: suffix,
  );
}

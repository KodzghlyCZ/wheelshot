import '../data/rim_catalog.dart';
import '../data/tire_size.dart';
import 'session_specs.dart';
import 'shoot_plan.dart';

/// Dial state for the shoot steps. Saved into the session specs so the
/// specs screen opens on the same numbers.
class SpecDraft {
  SpecDraft({required this.tires, required this.rims});

  final List<TireDraft> tires;
  final List<RimDraft> rims;
  SessionSpecs base = const SessionSpecs();

  factory SpecDraft.empty({required int tireCount, required int rimCount}) {
    return SpecDraft(
      tires: List.generate(tireCount, (_) => TireDraft()),
      rims: List.generate(rimCount, (_) => RimDraft()),
    );
  }

  void applySaved(SessionSpecs saved) {
    base = saved;
    for (var i = 0; i < tires.length && i < saved.tires.length; i++) {
      tires[i].apply(saved.tires[i]);
    }
    for (var i = 0; i < rims.length && i < saved.rims.length; i++) {
      rims[i].apply(saved.rims[i]);
    }
  }

  SessionSpecs toSpecs() => SessionSpecs(
        notes: base.notes,
        tires: [
          for (var i = 0; i < tires.length; i++)
            tires[i].toSpecs(
              i < base.tires.length ? base.tires[i] : const TireSpecs(),
            ),
        ],
        rims: [
          for (var i = 0; i < rims.length; i++)
            rims[i].toSpecs(
              i < base.rims.length ? base.rims[i] : const RimSpecs(),
            ),
        ],
      );
}

class TireDraft {
  String prefix = '';
  int width = 225;
  int aspect = 40;
  String construction = 'R';
  int diameter = 18;
  String suffix = '';
  int dotWeek = 1;
  int dotYear = 23;
  List<double> treadDepths = [3.0];
  String? sizeManual;
  String? dotManual;

  /// Null keeps the value already in the session. Empty string drops it.
  String? sizeOut;
  String? dotOut;
  String? treadOut;

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

  void apply(TireSpecs specs) {
    final size = tryParseTireSize(specs.size);
    if (size != null) {
      prefix = size.prefix;
      width = size.width;
      aspect = size.aspect;
      construction = size.construction;
      diameter = size.diameter;
      suffix = size.suffix;
      sizeManual = null;
    } else if (specs.size.trim().isNotEmpty) {
      sizeManual = specs.size.trim();
    }
    final dot = specs.dot.replaceAll(RegExp(r'\D'), '');
    if (dot.length == 4) {
      final week = int.tryParse(dot.substring(0, 2));
      final year = int.tryParse(dot.substring(2));
      if (week != null && year != null) {
        dotWeek = week;
        dotYear = year;
        dotManual = null;
      }
    } else if (dot.isNotEmpty) {
      dotManual = dot;
    }
    final depths = <double>[];
    for (final part in specs.treadMm.split(RegExp(r'\s*[,;/|]\s*'))) {
      final n = double.tryParse(part.trim().replaceAll(',', '.'));
      if (n != null) depths.add(n);
    }
    if (depths.isNotEmpty) treadDepths = depths;
  }

  void keepSize() {
    sizeOut = (sizeManual != null && sizeManual!.trim().isNotEmpty)
        ? sizeManual!.trim()
        : sizeLabel;
  }

  void keepDot() {
    dotOut = (dotManual != null && dotManual!.trim().isNotEmpty)
        ? dotManual!.trim()
        : dotLabel;
  }

  void keepTread() {
    treadOut = treadDepths.map(_mm).join(', ');
  }

  TireSpecs toSpecs(TireSpecs prior) => TireSpecs(
        brand: prior.brand,
        model: prior.model,
        size: sizeOut ?? prior.size,
        dot: dotOut ?? prior.dot,
        treadMm: treadOut ?? prior.treadMm,
        season: prior.season,
        extraLoad: prior.extraLoad,
        runFlat: prior.runFlat,
      );
}

class RimDraft {
  String brand = '';
  int pcdBolts = 5;
  double pcdDiameter = 112;
  double width = 7.5;
  int diameter = 18;
  int et = 35;
  double? centerBore = 57.1;
  String? pcdManual;
  String? sizeManual;

  /// Null keeps the value already in the session. Empty string drops it.
  String? brandOut;
  String? pcdOut;
  String? cbOut;
  String? etOut;
  String? sizeOut;

  bool get pcdLockedToText =>
      pcdManual != null && pcdManual!.trim().isNotEmpty;

  void apply(RimSpecs specs) {
    if (specs.brand.trim().isNotEmpty) brand = specs.brand.trim();
    final pcd = RegExp(r'(\d+)\s*[x×]\s*([\d.]+)', caseSensitive: false)
        .firstMatch(specs.pcd);
    if (pcd != null) {
      final bolts = int.tryParse(pcd.group(1)!);
      final dia = double.tryParse(pcd.group(2)!);
      if (bolts != null &&
          dia != null &&
          kPcdBoltCounts.contains(bolts) &&
          kPcdDiameters.contains(dia)) {
        pcdBolts = bolts;
        pcdDiameter = dia;
        pcdManual = null;
      }
    }
    final etMatch = RegExp(r'-?\d+').firstMatch(specs.et);
    if (etMatch != null) {
      final v = int.tryParse(etMatch.group(0)!);
      if (v != null && kEtValues.contains(v)) et = v;
    }
    final size = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*J?\s*[x×]\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(specs.size);
    if (size != null) {
      final w = double.tryParse(size.group(1)!.replaceAll(',', '.'));
      final d = int.tryParse(size.group(2)!);
      if (w != null &&
          d != null &&
          kRimWidths.contains(w) &&
          kRimDiameters.contains(d)) {
        width = w;
        diameter = d;
      }
    }
    final cb = double.tryParse(specs.centerBore.replaceAll(',', '.'));
    if (cb != null && kCommonCenterBores.contains(cb)) centerBore = cb;
  }

  String get pcdLabel => pcdLockedToText
      ? pcdManual!.trim()
      : formatPcd(pcdBolts, pcdDiameter);

  String get sizeLabel => (sizeManual != null && sizeManual!.trim().isNotEmpty)
      ? sizeManual!.trim()
      : (width == width.roundToDouble()
          ? '${width.toInt()}Jx$diameter'
          : '${width}Jx$diameter');

  String get cbLabel => centerBore == null ? '' : _mm(centerBore!);

  void keepHub() {
    pcdOut = pcdLabel;
    cbOut = cbLabel;
    etOut = 'ET$et';
  }

  void keepBrand() => brandOut = brand.trim();

  void keepRimSize() => sizeOut = sizeLabel;

  void keepEt() => etOut = 'ET$et';

  RimSpecs toSpecs(RimSpecs prior) => RimSpecs(
        brand: brandOut ?? prior.brand,
        pcd: pcdOut ?? prior.pcd,
        et: etOut ?? prior.et,
        size: sizeOut ?? prior.size,
        centerBore: cbOut ?? prior.centerBore,
        oem: prior.oem,
      );
}

void commitStep(SpecDraft draft, ShotStep step) {
  switch (step.dials) {
    case ShotDials.tireSize:
      _tireAt(draft, step.specIndex)?.keepSize();
    case ShotDials.tread:
      _tireAt(draft, step.specIndex)?.keepTread();
    case ShotDials.dot:
      _tireAt(draft, step.specIndex)?.keepDot();
    case ShotDials.hub:
      final rim = _rimAt(draft, step.specIndex);
      rim?.keepHub();
    case ShotDials.brand:
      _rimAt(draft, step.specIndex)?.keepBrand();
    case ShotDials.rimSize:
      _rimAt(draft, step.specIndex)?.keepRimSize();
    case ShotDials.et:
      _rimAt(draft, step.specIndex)?.keepEt();
    case ShotDials.none:
      break;
  }
}

void discardStep(SpecDraft draft, ShotStep step, {String? restoreEt}) {
  switch (step.dials) {
    case ShotDials.tireSize:
      final t = _tireAt(draft, step.specIndex);
      if (t != null) t.sizeOut = '';
    case ShotDials.tread:
      final t = _tireAt(draft, step.specIndex);
      if (t != null) t.treadOut = '';
    case ShotDials.dot:
      final t = _tireAt(draft, step.specIndex);
      if (t != null) t.dotOut = '';
    case ShotDials.hub:
      final rim = _rimAt(draft, step.specIndex);
      if (rim != null) {
        rim.pcdOut = '';
        rim.cbOut = '';
        rim.etOut = '';
      }
    case ShotDials.brand:
      _rimAt(draft, step.specIndex)?.brandOut = '';
    case ShotDials.rimSize:
      _rimAt(draft, step.specIndex)?.sizeOut = '';
    case ShotDials.et:
      _rimAt(draft, step.specIndex)?.etOut = restoreEt;
    case ShotDials.none:
      break;
  }
}

RimDraft? _rimAt(SpecDraft draft, int index) {
  if (index < 0 || index >= draft.rims.length) return null;
  return draft.rims[index];
}

TireDraft? _tireAt(SpecDraft draft, int index) {
  if (index < 0 || index >= draft.tires.length) return null;
  return draft.tires[index];
}

String _mm(double d) => d == d.roundToDouble()
    ? d.toInt().toString()
    : ((d * 100).round() % 10 == 0
        ? d.toStringAsFixed(1)
        : d.toStringAsFixed(2));

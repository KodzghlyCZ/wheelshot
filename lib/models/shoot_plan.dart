/// What the user is photographing.
enum ShootCategory {
  wheelSet,
  rimsOnly,
  tiresOnly,
  spare,
}

extension ShootCategoryX on ShootCategory {
  String get title => switch (this) {
        ShootCategory.wheelSet => 'Wheel set (rim + tire)',
        ShootCategory.rimsOnly => 'Separate rims',
        ShootCategory.tiresOnly => 'Separate tires',
        ShootCategory.spare => 'Spare tire',
      };

  String get subtitle => switch (this) {
        ShootCategory.wheelSet =>
          'Mounted wheels — pick piece count + tire/rim types',
        ShootCategory.rimsOnly =>
          'Bare rims — brand, size, ET; group by type',
        ShootCategory.tiresOnly =>
          'Loose tires — overall, tread, DOT, size by type',
        ShootCategory.spare =>
          'One spare — tire shots (+ rim if mounted)',
      };

  bool get includesTire => this != ShootCategory.rimsOnly;
  bool get includesRim =>
      this == ShootCategory.wheelSet || this == ShootCategory.rimsOnly;
  bool get usesShootConfig => this != ShootCategory.spare;
}

/// Flexible set configuration.
class ShootConfig {
  const ShootConfig({
    this.pieceCount = 4,
    this.tireTypes = 1,
    this.rimTypes = 1,
    this.rimsDifferByAxis = false,
    this.etOnlyByAxis = false,
  });

  final int pieceCount;
  final int tireTypes;
  final int rimTypes;
  final bool rimsDifferByAxis;
  final bool etOnlyByAxis;

  ShootConfig forCategory(ShootCategory category) {
    final pieces = pieceCount.clamp(1, 4);
    var tires = category.includesTire ? tireTypes.clamp(1, pieces) : 0;
    var rims = category.includesRim ? rimTypes.clamp(1, pieces) : 0;

    var etOnly = etOnlyByAxis && category.includesRim && rims > 1;
    var axis = (rimsDifferByAxis || etOnly) && category.includesRim && rims > 1;

    if (etOnly && category.includesTire && tires < 1) tires = 1;
    if (!category.includesTire) tires = 0;
    if (!category.includesRim) {
      rims = 0;
      etOnly = false;
      axis = false;
    }

    return ShootConfig(
      pieceCount: pieces,
      tireTypes: tires == 0 ? 1 : tires,
      rimTypes: rims == 0 ? 1 : rims,
      rimsDifferByAxis: axis,
      etOnlyByAxis: etOnly,
    );
  }

  String get label {
    final parts = <String>['$pieceCount×'];
    if (tireTypes > 0) parts.add('T$tireTypes');
    if (rimTypes > 0) parts.add('R$rimTypes');
    if (etOnlyByAxis) {
      parts.add('ET-axis');
    } else if (rimsDifferByAxis) {
      parts.add('axis-rims');
    }
    return parts.join(' ');
  }

  String get mixNote {
    final buf = StringBuffer('$pieceCount piece(s)');
    buf.write(', $tireTypes tire type(s), $rimTypes rim type(s)');
    if (etOnlyByAxis) {
      buf.write('; same rim face, ET differs by axis');
    } else if (rimsDifferByAxis) {
      buf.write('; rims differ by axis (width and/or ET)');
    }
    return buf.toString();
  }

  /// Specs: separate rim/tire sections — do not max() them together.
  int get rimSpecSlots => rimTypes.clamp(1, 4);
  int get tireSpecSlots => tireTypes.clamp(1, 4);

  bool get needsSetupEtHints => etOnlyByAxis && rimTypes > 1;

  static ShootConfig preset4() =>
      const ShootConfig(pieceCount: 4, tireTypes: 1, rimTypes: 1);

  static ShootConfig preset2plus2() =>
      const ShootConfig(pieceCount: 4, tireTypes: 2, rimTypes: 2);

  static ShootConfig preset3plus1() =>
      const ShootConfig(pieceCount: 4, tireTypes: 2, rimTypes: 2);

  static ShootConfig preset4minus2() => const ShootConfig(
        pieceCount: 4,
        tireTypes: 1,
        rimTypes: 2,
        rimsDifferByAxis: true,
        etOnlyByAxis: true,
      );
}

class ShotStep {
  const ShotStep({
    required this.id,
    required this.title,
    required this.hint,
    this.preferTorch = false,
    this.guide = ShotGuide.none,
    this.isExtra = false,
  });

  final String id;
  final String title;
  final String hint;
  final bool preferTorch;
  final ShotGuide guide;
  final bool isExtra;
}

enum ShotGuide {
  none,
  overallFrame,
  treadSurface,
  dotCloseup,
  sidewallSize,
  rimStamp,
}

List<ShotStep> buildWizard({
  required ShootCategory category,
  ShootConfig config = const ShootConfig(),
  bool spareHasRim = false,
  List<String> etNotes = const [],
}) {
  if (category == ShootCategory.spare) {
    final steps = <ShotStep>[..._tireFullSteps(prefix: '', filePrefix: '01')];
    if (spareHasRim) {
      steps.addAll(_rimSteps(prefix: '', filePrefix: '01'));
    }
    return steps;
  }

  final c = config.forCategory(category);
  final steps = <ShotStep>[];

  final tireCount = category.includesTire ? c.tireTypes : 0;
  final rimCount = category.includesRim ? c.rimTypes : 0;

  // --- Tires ---
  if (tireCount >= 1) {
    // Multi-piece / multi-type: one set overall, then per-type details (no
    // repeated overall). Single piece + single type: full tire block.
    final sharedOverall = c.pieceCount > 1 || tireCount > 1;
    if (sharedOverall) {
      steps.add(
        const ShotStep(
          id: 'set_overall',
          title: 'Set · overall',
          hint: 'Stand back. Capture the whole set / group once so the '
              'listing shows what is included.',
          guide: ShotGuide.overallFrame,
        ),
      );
      for (var t = 1; t <= tireCount; t++) {
        final label = tireCount == 1 ? 'Tire' : 'Tire type $t';
        final fp = tireCount == 1 ? 'type1' : 'tire$t';
        steps.addAll(
          _tireDetailSteps(prefix: '$label · ', filePrefix: fp),
        );
      }
    } else {
      steps.addAll(
        _tireFullSteps(prefix: 'Tire · ', filePrefix: 'type1'),
      );
    }
  }

  // --- Rims ---
  if (!category.includesRim || rimCount < 1) return steps;

  if (c.etOnlyByAxis && rimCount > 1) {
    steps.addAll(
      _rimFaceSteps(prefix: 'Shared rim · ', filePrefix: 'shared'),
    );
    for (var r = 1; r <= rimCount; r++) {
      final note = r <= etNotes.length ? etNotes[r - 1] : null;
      steps.add(
        _etStep(
          prefix: 'Rim type $r · ',
          filePrefix: 'type$r',
          etNote: note,
        ),
      );
    }
    return steps;
  }

  for (var r = 1; r <= rimCount; r++) {
    final label = rimCount == 1 ? 'Rim' : 'Rim type $r';
    final filePrefix = (rimCount == 1)
        ? 'type1'
        : (tireCount <= 1 ? 'type$r' : 'rim$r');
    final note = r <= etNotes.length ? etNotes[r - 1] : null;
    steps.addAll(_rimFaceSteps(prefix: '$label · ', filePrefix: filePrefix));
    steps.add(
      _etStep(prefix: '$label · ', filePrefix: filePrefix, etNote: note),
    );
  }

  return steps;
}

/// Optional extras after the main wizard (imperfections, etc.).
ShotStep extraShotStep(int index) => ShotStep(
      id: 'extra_${index.toString().padLeft(2, '0')}',
      title: 'Extra · photo $index',
      hint: 'Any imperfection, detail, or angle you want on the listing. '
          'Shoot as many as you need, then press Done.',
      guide: ShotGuide.none,
      isExtra: true,
    );

List<ShotStep> _tireFullSteps({
  required String prefix,
  required String filePrefix,
}) =>
    [
      ShotStep(
        id: '${filePrefix}_tire_overall',
        title: '${prefix}overall',
        hint: 'Stand back. Capture the whole tire (and wheel if mounted). '
            'Keep it centered and well lit.',
        guide: ShotGuide.overallFrame,
      ),
      ..._tireDetailSteps(prefix: prefix, filePrefix: filePrefix),
    ];

List<ShotStep> _tireDetailSteps({
  required String prefix,
  required String filePrefix,
}) =>
    [
      ShotStep(
        id: '${filePrefix}_tire_surface',
        title: '${prefix}tread / surface',
        hint: 'Shoot the contact patch / tread face. Fill the frame with '
            'tread so wear and damage are obvious.',
        guide: ShotGuide.treadSurface,
      ),
      ShotStep(
        id: '${filePrefix}_tire_dot',
        title: '${prefix}DOT / date code',
        hint: 'Close-up of the DOT oval (4-digit week/year, e.g. 0423). '
            'Torch will turn on — hold steady.',
        preferTorch: true,
        guide: ShotGuide.dotCloseup,
      ),
      ShotStep(
        id: '${filePrefix}_tire_size',
        title: '${prefix}size marking',
        hint: 'Sidewall size line, e.g. 225/40 ZR18 (92Y) EXTRA LOAD. '
            'Make every character readable.',
        preferTorch: true,
        guide: ShotGuide.sidewallSize,
      ),
    ];

List<ShotStep> _rimFaceSteps({
  required String prefix,
  required String filePrefix,
}) =>
    [
      ShotStep(
        id: '${filePrefix}_rim_overall',
        title: '${prefix}overall',
        hint: 'Whole rim face. Show spokes, finish, and any curb rash.',
        guide: ShotGuide.overallFrame,
      ),
      ShotStep(
        id: '${filePrefix}_rim_brand',
        title: '${prefix}brand stamp',
        hint: 'Close-up of maker stamp (e.g. Honda Motor Co., Ltd.).',
        preferTorch: true,
        guide: ShotGuide.rimStamp,
      ),
      ShotStep(
        id: '${filePrefix}_rim_size',
        title: '${prefix}size (width × diameter)',
        hint: 'Stamp like 18x7 1/2J — width, diameter, flange.',
        preferTorch: true,
        guide: ShotGuide.rimStamp,
      ),
    ];

ShotStep _etStep({
  required String prefix,
  required String filePrefix,
  String? etNote,
}) {
  final note = (etNote != null && etNote.trim().isNotEmpty)
      ? ' Noted ET: ${etNote.trim()}.'
      : '';
  return ShotStep(
    id: '${filePrefix}_rim_et',
    title: '${prefix}ET',
    hint: 'Offset / ET stamp for this type.$note '
        'Fill the frame with the number.',
    preferTorch: true,
    guide: ShotGuide.rimStamp,
  );
}

List<ShotStep> _rimSteps({
  required String prefix,
  required String filePrefix,
}) =>
    [
      ..._rimFaceSteps(prefix: prefix, filePrefix: filePrefix),
      _etStep(prefix: prefix, filePrefix: filePrefix),
    ];

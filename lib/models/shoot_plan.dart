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
        ShootCategory.rimsOnly => 'Bare rims — brand, size, ET; group by type',
        ShootCategory.tiresOnly =>
          'Loose tires — overall, tread, DOT, size by type',
        ShootCategory.spare => 'One spare — tire shots (+ rim if mounted)',
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

  /// One tread reading per physical tire of a type (4 pcs / 2 types → 2).
  int get maxTreadDepthsPerType {
    final types = tireTypes.clamp(1, 4);
    return (pieceCount.clamp(1, 4) / types).ceil().clamp(1, 4);
  }

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

enum ShotDials { none, tireSize, tread, dot, hub, brand, rimSize, et }

class ShotStep {
  const ShotStep({
    required this.id,
    required this.title,
    required this.hint,
    this.preferTorch = false,
    this.guide = ShotGuide.none,
    this.isExtra = false,
    this.dials = ShotDials.none,
    this.specIndex = 0,
  });

  final String id;
  final String title;
  final String hint;
  final bool preferTorch;
  final ShotGuide guide;
  final bool isExtra;

  /// Which spec dials sit under the preview. [none] is photo only.
  final ShotDials dials;

  /// Type index for rim dials and per-type tire dials.
  final int specIndex;
}

enum ShotGuide {
  none,
  overallFrame,
  treadSurface,
  dotCloseup,
  sidewallSize,
  rimStamp,
  centerHub,
}

List<ShotStep> buildWizard({
  required ShootCategory category,
  ShootConfig config = const ShootConfig(),
  bool spareHasRim = false,
  List<String> etNotes = const [],
}) {
  if (category == ShootCategory.spare) {
    final steps = <ShotStep>[
      ..._leadShots(pieces: 1),
      ..._tireShots(tireTypes: 1),
    ];
    if (spareHasRim) {
      steps.addAll(_rimTypeShots(prefix: 'Rim · ', filePrefix: '01', index: 0));
    }
    return steps;
  }

  final c = config.forCategory(category);
  final steps = <ShotStep>[..._leadShots(pieces: c.pieceCount)];

  if (category.includesTire) {
    steps.addAll(_tireShots(tireTypes: c.tireTypes));
  }
  if (!category.includesRim) return steps;

  final rimCount = c.rimTypes;
  if (c.etOnlyByAxis && rimCount > 1) {
    steps.addAll(
      _rimFaceShots(prefix: 'Shared rim · ', filePrefix: 'shared', index: 0),
    );
    for (var r = 0; r < rimCount; r++) {
      final note = r < etNotes.length ? etNotes[r] : null;
      steps.add(
        _etShot(
          prefix: 'Rim type ${r + 1} · ',
          filePrefix: 'type${r + 1}',
          index: r,
          etNote: note,
        ),
      );
    }
    return steps;
  }

  final tireCount = category.includesTire ? c.tireTypes : 0;
  for (var r = 0; r < rimCount; r++) {
    final label = rimCount == 1 ? 'Rim' : 'Rim type ${r + 1}';
    final filePrefix = rimCount == 1
        ? 'type1'
        : (tireCount <= 1 ? 'type${r + 1}' : 'rim${r + 1}');
    final note = r < etNotes.length ? etNotes[r] : null;
    steps.addAll(
      _rimTypeShots(
        prefix: '$label · ',
        filePrefix: filePrefix,
        index: r,
        etNote: note,
      ),
    );
  }
  return steps;
}

/// Overall, then one loose piece when the listing has more than one.
List<ShotStep> _leadShots({required int pieces}) => [
      ShotStep(
        id: 'set_overall',
        title: pieces > 1 ? 'Set · overall' : 'Overall',
        hint: pieces > 1
            ? 'Stand back. The whole set, once.'
            : 'Stand back. The whole piece, centered.',
        guide: ShotGuide.overallFrame,
      ),
      if (pieces > 1)
        const ShotStep(
          id: 'piece_individual',
          title: 'Individual piece',
          hint: 'One piece out of the set, on its own.',
          guide: ShotGuide.overallFrame,
        ),
    ];

/// Dimensions, tread, then DOT — one shoot block per tire type.
List<ShotStep> _tireShots({required int tireTypes}) {
  final n = tireTypes.clamp(1, 4);
  final steps = <ShotStep>[];
  for (var t = 0; t < n; t++) {
    final multi = n > 1;
    final label = multi ? 'Tire type ${t + 1}' : 'Tire';
    final fp = multi ? 'tire${t + 1}' : 'tires';
    steps.addAll([
      ShotStep(
        id: '${fp}_size',
        title: '$label · dimensions',
        hint: multi
            ? 'Sidewall size for type ${t + 1}. Match the dials.'
            : 'Sidewall size. Match the dials to the marking.',
        preferTorch: true,
        guide: ShotGuide.sidewallSize,
        dials: ShotDials.tireSize,
        specIndex: t,
      ),
      ShotStep(
        id: '${fp}_tread',
        title: '$label · tread',
        hint: multi
            ? 'Tread face for type ${t + 1}. Depth in millimetres.'
            : 'Tread face. Depth in millimetres. One dial per tire.',
        guide: ShotGuide.treadSurface,
        dials: ShotDials.tread,
        specIndex: t,
      ),
      ShotStep(
        id: '${fp}_dot',
        title: '$label · DOT',
        hint: multi
            ? 'DOT oval for type ${t + 1}. Week and year.'
            : 'DOT oval. Week and year.',
        preferTorch: true,
        guide: ShotGuide.dotCloseup,
        dials: ShotDials.dot,
        specIndex: t,
      ),
    ]);
  }
  return steps;
}

List<ShotStep> _rimTypeShots({
  required String prefix,
  required String filePrefix,
  required int index,
  String? etNote,
}) =>
    [
      ..._rimFaceShots(prefix: prefix, filePrefix: filePrefix, index: index),
      _etShot(
        prefix: prefix,
        filePrefix: filePrefix,
        index: index,
        etNote: etNote,
      ),
    ];

List<ShotStep> _rimFaceShots({
  required String prefix,
  required String filePrefix,
  required int index,
}) =>
    [
      ShotStep(
        id: '${filePrefix}_rim_hub',
        title: '${prefix}center hub',
        hint: 'Center bore on the dot. Bolt holes stay inside the circle.',
        guide: ShotGuide.centerHub,
        dials: ShotDials.hub,
        specIndex: index,
      ),
      ShotStep(
        id: '${filePrefix}_rim_brand',
        title: '${prefix}brand stamp',
        hint: 'Maker stamp, filling the frame. Pick the car maker.',
        preferTorch: true,
        guide: ShotGuide.rimStamp,
        dials: ShotDials.brand,
        specIndex: index,
      ),
      ShotStep(
        id: '${filePrefix}_rim_size',
        title: '${prefix}dimensions',
        hint: 'Width and diameter stamp.',
        preferTorch: true,
        guide: ShotGuide.rimStamp,
        dials: ShotDials.rimSize,
        specIndex: index,
      ),
    ];

/// Optional extras after the main wizard (imperfections, etc.).
ShotStep extraShotStep(int index) => ShotStep(
      id: 'extra_${index.toString().padLeft(2, '0')}',
      title: 'Extra · photo $index',
      hint: 'Any imperfection, detail, or angle you want on the listing. '
          'Shoot as many as you need, then press Done.',
      guide: ShotGuide.none,
      isExtra: true,
    );

ShotStep _etShot({
  required String prefix,
  required String filePrefix,
  required int index,
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
    dials: ShotDials.et,
    specIndex: index,
  );
}

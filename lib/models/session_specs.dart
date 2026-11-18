import 'dart:convert';

import 'shoot_plan.dart';

/// Manual fields entered after the photo wizard.
/// Non-empty values override photo reads (ad skill).
class RimSpecs {
  const RimSpecs({
    this.brand = '',
    this.pcd = '',
    this.et = '',
    this.size = '',
    this.centerBore = '',
    this.oem = '',
  });

  final String brand;
  final String pcd;
  final String et;
  final String size;
  final String centerBore;
  final String oem;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'pcd': pcd,
        'et': et,
        'size': size,
        'centerBore': centerBore,
        if (oem.trim().isNotEmpty) 'oem': oem,
      };

  factory RimSpecs.fromJson(Map<String, dynamic> j) => RimSpecs(
        brand: '${j['brand'] ?? ''}',
        pcd: '${j['pcd'] ?? ''}',
        et: '${j['et'] ?? ''}',
        size: '${j['size'] ?? ''}',
        centerBore: '${j['centerBore'] ?? j['center_bore'] ?? ''}',
        oem: '${j['oem'] ?? ''}',
      );
}

class TireSpecs {
  const TireSpecs({
    this.brand = '',
    this.model = '',
    this.size = '',
    this.dot = '',
    this.treadMm = '',
    this.season = '',
    this.extraLoad = false,
    this.runFlat = false,
  });

  final String brand;
  final String model;
  final String size;
  final String dot;
  final String treadMm;
  final bool extraLoad;
  final bool runFlat;

  /// `letni` | `zimni` | `celorocni` | empty
  final String season;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'size': size,
        'dot': dot,
        'treadMm': treadMm,
        'season': season,
        'extraLoad': extraLoad,
        'runFlat': runFlat,
      };

  factory TireSpecs.fromJson(Map<String, dynamic> j) => TireSpecs(
        brand: '${j['brand'] ?? ''}',
        model: '${j['model'] ?? ''}',
        size: '${j['size'] ?? ''}',
        dot: '${j['dot'] ?? ''}',
        treadMm: '${j['treadMm'] ?? j['tread_mm'] ?? ''}',
        season: '${j['season'] ?? ''}',
        extraLoad: j['extraLoad'] == true || j['extra_load'] == true,
        runFlat: j['runFlat'] == true || j['runflat'] == true,
      );
}

class SessionSpecs {
  const SessionSpecs({
    this.rims = const [],
    this.tires = const [],
    this.notes = '',
  });

  final List<RimSpecs> rims;
  final List<TireSpecs> tires;
  final String notes;

  Map<String, dynamic> toJson({
    required ShootCategory category,
    ShootConfig? config,
  }) =>
      {
        'version': 1,
        'category': category.name,
        if (config != null)
          'config': {
            'pieces': config.pieceCount,
            'tireTypes': config.tireTypes,
            'rimTypes': config.rimTypes,
            'rimsDifferByAxis': config.rimsDifferByAxis,
            'etOnlyByAxis': config.etOnlyByAxis,
            'layout': config.label,
          },
        'rims': rims.map((r) => r.toJson()).toList(),
        'tires': tires.map((t) => t.toJson()).toList(),
        'notes': notes,
      };

  String toJsonString({
    required ShootCategory category,
    ShootConfig? config,
  }) =>
      const JsonEncoder.withIndent('  ')
          .convert(toJson(category: category, config: config));

  factory SessionSpecs.fromJson(Map<String, dynamic> j) {
    final rims = <RimSpecs>[];
    final tires = <TireSpecs>[];
    final rawRims = j['rims'];
    if (rawRims is List) {
      for (final r in rawRims) {
        if (r is Map) {
          rims.add(RimSpecs.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }
    final rawTires = j['tires'];
    if (rawTires is List) {
      for (final t in rawTires) {
        if (t is Map) {
          tires.add(TireSpecs.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }
    return SessionSpecs(
      rims: rims,
      tires: tires,
      notes: '${j['notes'] ?? ''}',
    );
  }

  static SessionSpecs? tryParseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SessionSpecs.fromJson(decoded);
      if (decoded is Map) {
        return SessionSpecs.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  String toFileContents({
    required ShootCategory category,
    ShootConfig? config,
  }) {
    final buf = StringBuffer()
      ..writeln('# Manual specs — non-empty values override photo reads')
      ..writeln('category: ${category.name}');
    if (config != null) {
      buf
        ..writeln('layout: ${config.label}')
        ..writeln('pieces: ${config.pieceCount}')
        ..writeln('tire_types: ${config.tireTypes}')
        ..writeln('rim_types: ${config.rimTypes}')
        ..writeln('et_only_by_axis: ${config.etOnlyByAxis}');
    }
    buf.writeln('priority: manual_over_photo');
    buf.writeln();

    final etOnly = config?.etOnlyByAxis == true;

    if (rims.isNotEmpty) {
      final multi = rims.length > 1;
      for (var i = 0; i < rims.length; i++) {
        final r = rims[i];
        final prefix = multi ? 'rim${i + 1}_' : '';
        if (multi) buf.writeln('# Rim type ${i + 1}');
        void line(String key, String value) {
          final v = value.trim();
          if (v.isEmpty) return;
          buf.writeln('$prefix$key: $v');
        }

        final etOnlyExtra = etOnly && i > 0;
        if (!etOnlyExtra) {
          line('rim_brand', r.brand);
          line('pcd', r.pcd);
          line('rim_size', r.size);
          line('center_bore', r.centerBore);
          line('oem', r.oem);
        }
        line('et', r.et);
        if (multi) buf.writeln();
      }
    }

    if (category.includesTire && tires.isNotEmpty) {
      final multi = tires.length > 1;
      for (var i = 0; i < tires.length; i++) {
        final t = tires[i];
        final prefix = multi ? 'tire${i + 1}_' : '';
        if (multi) buf.writeln('# Tire type ${i + 1}');
        void line(String key, String value) {
          final v = value.trim();
          if (v.isEmpty) return;
          buf.writeln('$prefix$key: $v');
        }

        line('tire_brand', t.brand);
        line('tire_model', t.model);
        line('tire_size', t.size);
        line('dot', t.dot);
        line('tread_mm', t.treadMm);
        line('season', t.season);
        if (t.extraLoad) line('extra_load', 'true');
        if (t.runFlat) line('runflat', 'true');
        if (multi) buf.writeln();
      }
    }

    final n = notes.trim();
    if (n.isNotEmpty) {
      buf.writeln('notes: ${n.replaceAll('\n', ' | ')}');
    }
    return buf.toString();
  }
}

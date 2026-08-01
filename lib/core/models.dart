import 'dart:typed_data';

enum MeasurementType { compression, flexure }

extension MeasurementTypeLabel on MeasurementType {
  String get databaseValue => switch (this) {
    MeasurementType.compression => 'compression',
    MeasurementType.flexure => 'flexure',
  };

  String get label => switch (this) {
    MeasurementType.compression => 'Compresión',
    MeasurementType.flexure => 'Flexotracción',
  };

  String get massUnit => switch (this) {
    MeasurementType.compression => 'kg',
    MeasurementType.flexure => 'g',
  };

  static MeasurementType fromDatabase(String value) => switch (value) {
    'compression' => MeasurementType.compression,
    'flexure' => MeasurementType.flexure,
    _ => throw ArgumentError('Tipo de medición desconocido: $value'),
  };
}

class HistoricalSample {
  const HistoricalSample({
    required this.type,
    required this.modelCode,
    required this.dryMass,
    required this.saturatedMass,
    required this.immersedMass,
    required this.absorption,
    required this.density,
    this.naturalMass,
    this.thicknessMm,
  });

  final MeasurementType type;
  final String modelCode;
  final double dryMass;
  final double saturatedMass;
  final double immersedMass;
  final double? naturalMass;
  final double absorption;
  final double density;
  final double? thicknessMm;

  double? get moisturePercent {
    final natural = naturalMass;
    if (natural == null || dryMass <= 0) return null;
    final value = ((natural - dryMass) / dryMass) * 100;
    if (!value.isFinite || value < 0 || value > absorption + 0.5) return null;
    return value;
  }

  double? get specificDryMass {
    final thickness = thicknessMm;
    if (thickness == null || thickness <= 0) return null;
    return dryMass / thickness;
  }
}

class ModelSummary {
  const ModelSummary({
    required this.type,
    required this.modelCode,
    required this.totalSamples,
    required this.validSamples,
    required this.minAbsorption,
    required this.maxAbsorption,
    this.minThicknessMm,
    this.maxThicknessMm,
  });

  final MeasurementType type;
  final String modelCode;
  final int totalSamples;
  final int validSamples;
  final double minAbsorption;
  final double maxAbsorption;
  final double? minThicknessMm;
  final double? maxThicknessMm;

  bool get canPredict => validSamples >= 3;
}

class LaboratoryTrialTarget {
  const LaboratoryTrialTarget({required this.absorption, this.thicknessMm});

  final double absorption;
  final double? thicknessMm;
}

class MassScenario {
  const MassScenario({
    required this.label,
    required this.quantile,
    required this.dryMass,
    required this.saturatedMass,
    required this.immersedMass,
    required this.density,
    this.naturalMass,
  });

  final String label;
  final double quantile;
  final double dryMass;
  final double saturatedMass;
  final double immersedMass;
  final double? naturalMass;
  final double density;
}

class PredictionResult {
  const PredictionResult({
    required this.type,
    required this.modelCode,
    required this.targetAbsorption,
    required this.sampleCount,
    required this.confidence,
    required this.scenarios,
    required this.warnings,
    this.targetThicknessMm,
    this.historicalAbsorptionRange,
    this.historicalThicknessRange,
  });

  final MeasurementType type;
  final String modelCode;
  final double targetAbsorption;
  final double? targetThicknessMm;
  final int sampleCount;
  final String confidence;
  final List<MassScenario> scenarios;
  final List<String> warnings;
  final ({double min, double max})? historicalAbsorptionRange;
  final ({double min, double max})? historicalThicknessRange;

  MassScenario get typicalScenario {
    if (scenarios.isEmpty) {
      throw StateError('La predicción no contiene escenarios.');
    }
    return scenarios.firstWhere(
      (scenario) => scenario.quantile == 0.50,
      orElse: () => scenarios.reduce(
        (current, candidate) =>
            (candidate.quantile - 0.50).abs() < (current.quantile - 0.50).abs()
            ? candidate
            : current,
      ),
    );
  }
}

class ImportSummary {
  const ImportSummary({
    required this.fileName,
    required this.detectedType,
    required this.totalSpecimens,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.rejected,
    required this.validForPrediction,
    required this.alreadyImported,
    required this.notes,
  });

  final String fileName;
  final MeasurementType? detectedType;
  final int totalSpecimens;
  final int inserted;
  final int updated;
  final int unchanged;
  final int rejected;
  final int validForPrediction;
  final bool alreadyImported;
  final List<String> notes;

  factory ImportSummary.fromMap(Map<Object?, Object?> map) {
    final typeValue = map['detectedType'] as String?;
    return ImportSummary(
      fileName: map['fileName'] as String? ?? 'archivo.xlsx',
      detectedType: typeValue == null
          ? null
          : MeasurementTypeLabel.fromDatabase(typeValue),
      totalSpecimens: (map['totalSpecimens'] as num?)?.toInt() ?? 0,
      inserted: (map['inserted'] as num?)?.toInt() ?? 0,
      updated: (map['updated'] as num?)?.toInt() ?? 0,
      unchanged: (map['unchanged'] as num?)?.toInt() ?? 0,
      rejected: (map['rejected'] as num?)?.toInt() ?? 0,
      validForPrediction: (map['validForPrediction'] as num?)?.toInt() ?? 0,
      alreadyImported: map['alreadyImported'] as bool? ?? false,
      notes: (map['notes'] as List<Object?>? ?? const <Object?>[])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

class ImportPayload {
  const ImportPayload({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.type,
    required this.importedAt,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.rejected,
  });

  final int id;
  final String fileName;
  final MeasurementType type;
  final DateTime importedAt;
  final int inserted;
  final int updated;
  final int unchanged;
  final int rejected;
}

class AppStats {
  const AppStats({
    required this.totalMeasurements,
    required this.validMeasurements,
    required this.compressionModels,
    required this.flexureModels,
    required this.importBatches,
  });

  final int totalMeasurements;
  final int validMeasurements;
  final int compressionModels;
  final int flexureModels;
  final int importBatches;

  static const empty = AppStats(
    totalMeasurements: 0,
    validMeasurements: 0,
    compressionModels: 0,
    flexureModels: 0,
    importBatches: 0,
  );
}

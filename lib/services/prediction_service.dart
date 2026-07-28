import 'dart:math' as math;

import '../core/models.dart';
import '../core/statistics.dart';

class PredictionService {
  const PredictionService();

  PredictionResult predict({
    required MeasurementType type,
    required String modelCode,
    required List<HistoricalSample> sourceSamples,
    required double targetAbsorption,
    double? targetThicknessMm,
  }) {
    if (sourceSamples.length < 3) {
      throw StateError(
        'El modelo necesita al menos 3 especímenes válidos para calcular.',
      );
    }
    if (!targetAbsorption.isFinite ||
        targetAbsorption < 0 ||
        targetAbsorption > 30) {
      throw ArgumentError('La absorción debe estar entre 0 y 30 %.');
    }
    if (type == MeasurementType.flexure &&
        (targetThicknessMm == null ||
            !targetThicknessMm.isFinite ||
            targetThicknessMm < 10 ||
            targetThicknessMm > 300)) {
      throw ArgumentError('El espesor debe estar entre 10 y 300 mm.');
    }

    var samples = sourceSamples.where(_isPhysicallyValid).toList();
    if (type == MeasurementType.flexure) {
      samples = samples
          .where((sample) => sample.specificDryMass != null)
          .toList(growable: false);
      samples = Statistics.filterByMad(
        samples,
        (sample) => sample.specificDryMass!,
      );
    } else {
      samples = Statistics.filterByMad(samples, (sample) => sample.dryMass);
    }
    samples = Statistics.filterByMad(samples, (sample) => sample.density);

    if (samples.length < 3) {
      throw StateError(
        'Después del control de calidad quedaron menos de 3 datos utilizables.',
      );
    }

    final absorptionRange = (
      min: samples.map((sample) => sample.absorption).reduce(math.min),
      max: samples.map((sample) => sample.absorption).reduce(math.max),
    );
    final thicknessValues = samples
        .map((sample) => sample.thicknessMm)
        .whereType<double>()
        .toList(growable: false);
    final thicknessRange = thicknessValues.isEmpty
        ? null
        : (
            min: thicknessValues.reduce(math.min),
            max: thicknessValues.reduce(math.max),
          );

    final warnings = <String>[];
    if (targetAbsorption < absorptionRange.min ||
        targetAbsorption > absorptionRange.max) {
      warnings.add(
        'La absorción solicitada está fuera del rango histórico '
        '(${absorptionRange.min.toStringAsFixed(2)}–'
        '${absorptionRange.max.toStringAsFixed(2)} %). El resultado es una extrapolación.',
      );
    }
    if (type == MeasurementType.flexure && thicknessRange != null) {
      final thickness = targetThicknessMm!;
      if (thickness < thicknessRange.min || thickness > thicknessRange.max) {
        warnings.add(
          'El espesor solicitado está fuera del rango histórico '
          '(${thicknessRange.min.toStringAsFixed(1)}–'
          '${thicknessRange.max.toStringAsFixed(1)} mm).',
        );
      }
    }

    const definitions = <({String label, double probability})>[
      (label: 'Bajo', probability: 0.15),
      (label: 'Típico', probability: 0.50),
      (label: 'Alto', probability: 0.85),
    ];

    final scenarios = definitions.map((definition) {
      final representative = Statistics.weightedRepresentative<HistoricalSample>(
        values: samples,
        metric: type == MeasurementType.compression
            ? (sample) => sample.dryMass
            : (sample) => sample.specificDryMass!,
        absorption: (sample) => sample.absorption,
        targetAbsorption: targetAbsorption,
        probability: definition.probability,
      );

      final dryMass = type == MeasurementType.compression
          ? representative.dryMass
          : representative.specificDryMass! * targetThicknessMm!;
      final density = representative.density.clamp(1200.0, 3000.0).toDouble();
      final saturatedMass = dryMass * (1 + targetAbsorption / 100);
      final immersedMass = saturatedMass - (dryMass * 1000 / density);

      double? naturalMass;
      if (type == MeasurementType.compression) {
        var moisture = representative.moisturePercent;
        moisture ??= _weightedMoistureFallback(
          samples,
          targetAbsorption,
        );
        moisture = moisture.clamp(0.0, targetAbsorption).toDouble();
        naturalMass = dryMass * (1 + moisture / 100);
        naturalMass = naturalMass.clamp(dryMass, saturatedMass).toDouble();
      }

      return MassScenario(
        label: definition.label,
        quantile: definition.probability,
        dryMass: dryMass,
        saturatedMass: saturatedMass,
        immersedMass: immersedMass,
        naturalMass: naturalMass,
        density: density,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.dryMass.compareTo(b.dryMass));

    final confidence = _confidence(
      sampleCount: samples.length,
      targetAbsorption: targetAbsorption,
      absorptionRange: absorptionRange,
      targetThickness: targetThicknessMm,
      thicknessRange: thicknessRange,
    );

    return PredictionResult(
      type: type,
      modelCode: modelCode,
      targetAbsorption: targetAbsorption,
      targetThicknessMm: targetThicknessMm,
      sampleCount: samples.length,
      confidence: confidence,
      scenarios: scenarios,
      warnings: warnings,
      historicalAbsorptionRange: absorptionRange,
      historicalThicknessRange: thicknessRange,
    );
  }

  bool _isPhysicallyValid(HistoricalSample sample) {
    return sample.dryMass > 0 &&
        sample.saturatedMass >= sample.dryMass &&
        sample.immersedMass >= 0 &&
        sample.immersedMass < sample.saturatedMass &&
        sample.absorption >= 0 &&
        sample.absorption <= 30 &&
        sample.density >= 1200 &&
        sample.density <= 3000;
  }

  double _weightedMoistureFallback(
    List<HistoricalSample> samples,
    double targetAbsorption,
  ) {
    final withMoisture = samples
        .where((sample) => sample.moisturePercent != null)
        .toList(growable: false);
    if (withMoisture.isEmpty) {
      return math.min(targetAbsorption * 0.5, 3.0);
    }
    final representative = Statistics.weightedRepresentative<HistoricalSample>(
      values: withMoisture,
      metric: (sample) => sample.moisturePercent!,
      absorption: (sample) => sample.absorption,
      targetAbsorption: targetAbsorption,
      probability: 0.5,
    );
    return representative.moisturePercent!;
  }

  String _confidence({
    required int sampleCount,
    required double targetAbsorption,
    required ({double min, double max}) absorptionRange,
    required double? targetThickness,
    required ({double min, double max})? thicknessRange,
  }) {
    final absorptionInside = targetAbsorption >= absorptionRange.min &&
        targetAbsorption <= absorptionRange.max;
    final thicknessInside = targetThickness == null ||
        thicknessRange == null ||
        (targetThickness >= thicknessRange.min &&
            targetThickness <= thicknessRange.max);

    if (sampleCount >= 30 && absorptionInside && thicknessInside) return 'Alta';
    if (sampleCount >= 10 && absorptionInside && thicknessInside) return 'Media';
    return 'Baja';
  }
}

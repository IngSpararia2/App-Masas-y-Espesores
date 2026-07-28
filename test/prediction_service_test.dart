import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/core/models.dart';
import 'package:masalab_historico/services/prediction_service.dart';

void main() {
  const service = PredictionService();

  test('compresión conserva ecuaciones físicas', () {
    final samples = <HistoricalSample>[
      _compression(10.2, 6.1, 2020, 10.5),
      _compression(10.5, 6.4, 2040, 10.8),
      _compression(10.7, 6.8, 2060, 11.0),
      _compression(10.9, 7.0, 2080, 11.2),
      _compression(11.1, 7.2, 2100, 11.4),
    ];

    final result = service.predict(
      type: MeasurementType.compression,
      modelCode: 'M12L-DIV',
      sourceSamples: samples,
      targetAbsorption: 6,
    );

    expect(result.scenarios.length, 3);
    for (final scenario in result.scenarios) {
      expect(
        scenario.saturatedMass,
        closeTo(scenario.dryMass * 1.06, 1e-9),
      );
      expect(
        scenario.immersedMass,
        closeTo(
          scenario.saturatedMass - scenario.dryMass * 1000 / scenario.density,
          1e-9,
        ),
      );
      expect(scenario.naturalMass, isNotNull);
      expect(scenario.naturalMass!, inInclusiveRange(
        scenario.dryMass,
        scenario.saturatedMass,
      ));
    }
  });

  test('flexotracción escala la masa con el espesor', () {
    final samples = <HistoricalSample>[
      _flexure(3000, 78, 6.0, 2000),
      _flexure(3100, 80, 6.2, 2020),
      _flexure(3200, 82, 6.4, 2040),
      _flexure(3300, 84, 6.6, 2060),
      _flexure(3400, 86, 6.8, 2080),
    ];

    final result82 = service.predict(
      type: MeasurementType.flexure,
      modelCode: 'AR8',
      sourceSamples: samples,
      targetAbsorption: 6.4,
      targetThicknessMm: 82,
    );
    final result90 = service.predict(
      type: MeasurementType.flexure,
      modelCode: 'AR8',
      sourceSamples: samples,
      targetAbsorption: 6.4,
      targetThicknessMm: 90,
    );

    final typical82 = result82.scenarios[1].dryMass;
    final typical90 = result90.scenarios[1].dryMass;
    expect(typical90 / typical82, closeTo(90 / 82, 1e-9));
  });
}

HistoricalSample _compression(
  double dry,
  double absorption,
  double density,
  double natural,
) {
  final saturated = dry * (1 + absorption / 100);
  final immersed = saturated - dry * 1000 / density;
  return HistoricalSample(
    type: MeasurementType.compression,
    modelCode: 'M12L-DIV',
    dryMass: dry,
    saturatedMass: saturated,
    immersedMass: immersed,
    naturalMass: natural,
    absorption: absorption,
    density: density,
  );
}

HistoricalSample _flexure(
  double dry,
  double thickness,
  double absorption,
  double density,
) {
  final saturated = dry * (1 + absorption / 100);
  final immersed = saturated - dry * 1000 / density;
  return HistoricalSample(
    type: MeasurementType.flexure,
    modelCode: 'AR8',
    dryMass: dry,
    saturatedMass: saturated,
    immersedMass: immersed,
    absorption: absorption,
    density: density,
    thicknessMm: thickness,
  );
}

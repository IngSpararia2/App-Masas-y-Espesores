import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/core/statistics.dart';

void main() {
  test('calcula cuantiles con interpolación', () {
    expect(Statistics.quantile([1, 2, 3, 4, 5], 0.5), 3);
    expect(Statistics.quantile([1, 2, 3, 4], 0.25), closeTo(1.75, 1e-9));
  });

  test('filtro MAD elimina un valor extremo', () {
    final values = [10.0, 10.1, 9.9, 10.2, 9.8, 10.0, 10.1, 100.0];
    final filtered = Statistics.filterByMad(values, (value) => value);
    expect(filtered, isNot(contains(100.0)));
    expect(filtered.length, 7);
  });

  test('representante ponderado favorece absorciones cercanas', () {
    final values = [
      (mass: 10.0, absorption: 4.0),
      (mass: 11.0, absorption: 6.0),
      (mass: 12.0, absorption: 12.0),
    ];
    final representative = Statistics.weightedRepresentative(
      values: values,
      metric: (value) => value.mass,
      absorption: (value) => value.absorption,
      targetAbsorption: 6,
      probability: 0.5,
    );
    expect(representative.mass, 11.0);
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/core/laboratory_randomizer.dart';

void main() {
  group('LaboratoryRandomizer.nextHundredth', () {
    test('incluye ambos extremos del rango', () {
      final random = _SequenceRandom([0, 2]);
      final generator = LaboratoryRandomizer(random: random);

      expect(generator.nextHundredth(min: 1, max: 1.02), 1);
      expect(generator.nextHundredth(min: 1, max: 1.02), 1.02);
      expect(random.requestedMaxima, [3, 3]);
    });

    test('solo usa centésimas contenidas por límites fraccionarios', () {
      final generator = LaboratoryRandomizer(random: _SequenceRandom([0, 1]));

      expect(generator.nextHundredth(min: 1.001, max: 1.029), 1.01);
      expect(generator.nextHundredth(min: 1.001, max: 1.029), 1.02);
    });

    test('maneja rangos y límites negativos', () {
      final generator = LaboratoryRandomizer(random: _SequenceRandom([0, 2]));

      expect(generator.nextHundredth(min: -1.025, max: -0.995), -1.02);
      expect(generator.nextHundredth(min: -1.025, max: -0.995), -1);
    });

    test('devuelve el único valor de un rango degenerado', () {
      final random = _SequenceRandom([0]);
      final generator = LaboratoryRandomizer(random: random);

      expect(generator.nextHundredth(min: 6.25, max: 6.25), 6.25);
      expect(random.requestedMaxima, [1]);
    });

    test('tolera artefactos binarios en centésimas comunes', () {
      final generator = LaboratoryRandomizer(random: _SequenceRandom([0, 0]));

      expect(generator.nextHundredth(min: 0.29, max: 0.29), 0.29);
      expect(generator.nextHundredth(min: -0.29, max: -0.29), -0.29);
    });

    test('rechaza un intervalo sin ninguna centésima completa', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.nextHundredth(min: 1.001, max: 1.009),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('no contiene ninguna centésima'),
          ),
        ),
      );
    });

    test('rechaza un rango degenerado fuera de la grilla de centésimas', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.nextHundredth(min: 6.251, max: 6.251),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza límites invertidos', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.nextHundredth(min: 2, max: 1),
        throwsA(isA<RangeError>()),
      );
    });

    test('rechaza límites no finitos', () {
      final generator = LaboratoryRandomizer.seeded(1);

      for (final invalid in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => generator.nextHundredth(min: invalid, max: 1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => generator.nextHundredth(min: 0, max: invalid),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('rechaza un límite finito que desborda al escalarlo', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.nextHundredth(min: 0, max: double.maxFinite),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza intervalos mayores que la capacidad de Random.nextInt', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.nextHundredth(min: 0, max: 42949672.96),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('LaboratoryRandomizer.generateHundredths', () {
    test(
      'genera la cantidad solicitada reutilizando la secuencia aleatoria',
      () {
        final random = _SequenceRandom([0, 1, 2]);
        final generator = LaboratoryRandomizer(random: random);

        final values = generator.generateHundredths(
          min: 4.5,
          max: 4.52,
          count: 3,
        );

        expect(values, [4.5, 4.51, 4.52]);
        expect(random.requestedMaxima, [3, 3, 3]);
      },
    );

    test('produce una lista vacía sin consumir aleatoriedad', () {
      final random = _SequenceRandom(const []);
      final generator = LaboratoryRandomizer(random: random);

      final values = generator.generateHundredths(min: 2, max: 3, count: 0);

      expect(values, isEmpty);
      expect(random.requestedMaxima, isEmpty);
    });

    test('valida los límites aunque la cantidad sea cero', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.generateHundredths(
          min: double.nan,
          max: double.infinity,
          count: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza cantidades negativas', () {
      final generator = LaboratoryRandomizer.seeded(1);

      expect(
        () => generator.generateHundredths(min: 1, max: 2, count: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('un mismo seed reproduce exactamente la secuencia', () {
      final first = LaboratoryRandomizer.seeded(2026);
      final second = LaboratoryRandomizer.seeded(2026);

      final firstValues = first.generateHundredths(
        min: 5.25,
        max: 8.75,
        count: 100,
      );
      final secondValues = second.generateHundredths(
        min: 5.25,
        max: 8.75,
        count: 100,
      );

      expect(firstValues, secondValues);
    });

    test('todos los valores quedan en rango y en la grilla de centésimas', () {
      final generator = LaboratoryRandomizer.seeded(42);

      final values = generator.generateHundredths(
        min: 5.123,
        max: 8.877,
        count: 1000,
      );

      for (final value in values) {
        expect(value, inInclusiveRange(5.123, 8.877));
        expect(value * 100, closeTo((value * 100).roundToDouble(), 1e-9));
      }
    });
  });
}

class _SequenceRandom implements math.Random {
  _SequenceRandom(List<int> values) : _values = List<int>.of(values);

  final List<int> _values;
  final List<int> requestedMaxima = <int>[];
  var _index = 0;

  @override
  int nextInt(int max) {
    requestedMaxima.add(max);
    if (_index >= _values.length) {
      throw StateError('No quedan valores aleatorios configurados.');
    }
    final value = _values[_index++];
    if (value < 0 || value >= max) {
      throw StateError('El valor $value no pertenece a [0, $max).');
    }
    return value;
  }

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(1 << 26) / (1 << 26);
}

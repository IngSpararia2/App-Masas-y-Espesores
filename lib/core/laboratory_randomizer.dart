import 'dart:math' as math;

/// Generates laboratory input values on an exact hundredth grid.
///
/// Bounds are inclusive. When a bound has more than two decimal places, only
/// hundredths that remain inside the original interval are eligible. For
/// example, the interval `1.001`–`1.029` can produce `1.01` or `1.02`.
class LaboratoryRandomizer {
  LaboratoryRandomizer({math.Random? random})
    : _random = random ?? math.Random();

  LaboratoryRandomizer.seeded(int seed) : _random = math.Random(seed);

  static const int _hundredthsPerUnit = 100;
  static const int _maxRandomChoices = 1 << 32;

  final math.Random _random;

  /// Returns one value, with at most two decimal places, inside `[min, max]`.
  ///
  /// Throws an [ArgumentError] when either bound is not finite or when the
  /// interval contains no value representable as a hundredth. A [RangeError]
  /// is thrown when `min > max` or the interval is too large for
  /// [math.Random.nextInt].
  double nextHundredth({required double min, required double max}) {
    final range = _validatedHundredthRange(min: min, max: max);
    return _nextFromRange(range: range, min: min, max: max);
  }

  /// Generates [count] independent values using the same validated interval.
  List<double> generateHundredths({
    required double min,
    required double max,
    required int count,
  }) {
    if (count < 0) {
      throw RangeError.range(count, 0, null, 'count');
    }
    final range = _validatedHundredthRange(min: min, max: max);
    return List<double>.generate(
      count,
      (_) => _nextFromRange(range: range, min: min, max: max),
      growable: false,
    );
  }

  double _nextFromRange({
    required ({int first, int choiceCount}) range,
    required double min,
    required double max,
  }) {
    final selectedHundredths = range.first + _random.nextInt(range.choiceCount);
    final result = selectedHundredths / _hundredthsPerUnit;
    if (result < min || result > max) {
      throw ArgumentError(
        'Los límites [$min, $max] exceden la precisión numérica disponible.',
      );
    }
    return result;
  }

  static ({int first, int choiceCount}) _validatedHundredthRange({
    required double min,
    required double max,
  }) {
    _validateFinite(min, 'min');
    _validateFinite(max, 'max');
    if (min > max) {
      throw RangeError('min ($min) no puede ser mayor que max ($max).');
    }

    final minHundredths = _inclusiveLowerHundredth(min);
    final maxHundredths = _inclusiveUpperHundredth(max);
    if (minHundredths > maxHundredths) {
      throw ArgumentError(
        'El rango [$min, $max] no contiene ninguna centésima completa.',
      );
    }

    final choiceCount = maxHundredths - minHundredths + 1;
    if (choiceCount > _maxRandomChoices) {
      throw RangeError(
        'El rango contiene $choiceCount centésimas; el máximo compatible '
        'con Random.nextInt es $_maxRandomChoices.',
      );
    }
    return (first: minHundredths, choiceCount: choiceCount);
  }

  static void _validateFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Debe ser un número finito.');
    }
    final scaled = value * _hundredthsPerUnit;
    if (!scaled.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'Es demasiado grande para expresarlo en centésimas.',
      );
    }
  }

  static int _inclusiveLowerHundredth(double value) {
    final scaled = value * _hundredthsPerUnit;
    var hundredths = scaled.ceil();

    // Floating-point multiplication can place values such as 0.29 just above
    // an integer. Correct by comparing the reconstructed neighboring value.
    if ((hundredths - 1) / _hundredthsPerUnit >= value) {
      hundredths--;
    }
    if (hundredths / _hundredthsPerUnit < value) {
      hundredths++;
    }
    return hundredths;
  }

  static int _inclusiveUpperHundredth(double value) {
    final scaled = value * _hundredthsPerUnit;
    var hundredths = scaled.floor();

    // See [_inclusiveLowerHundredth] for the floating-point correction.
    if ((hundredths + 1) / _hundredthsPerUnit <= value) {
      hundredths++;
    }
    if (hundredths / _hundredthsPerUnit > value) {
      hundredths--;
    }
    return hundredths;
  }
}

import 'dart:math' as math;

class Statistics {
  const Statistics._();

  static double median(Iterable<double> values) => quantile(values, 0.5);

  static double quantile(Iterable<double> values, double probability) {
    final sorted = values.where((value) => value.isFinite).toList()..sort();
    if (sorted.isEmpty) {
      throw StateError('No hay valores válidos para calcular el cuantil.');
    }
    if (sorted.length == 1) return sorted.first;

    final p = probability.clamp(0.0, 1.0).toDouble();
    final position = (sorted.length - 1) * p;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }

  static double iqr(Iterable<double> values) {
    return quantile(values, 0.75) - quantile(values, 0.25);
  }

  static double mad(Iterable<double> values) {
    final list = values.where((value) => value.isFinite).toList();
    if (list.isEmpty) return 0;
    final center = median(list);
    return median(list.map((value) => (value - center).abs()));
  }

  static List<T> filterByMad<T>(
    List<T> values,
    double Function(T value) selector, {
    double zLimit = 4.5,
    int minimumCount = 8,
  }) {
    if (values.length < minimumCount) return List<T>.of(values);
    final metrics = values.map(selector).where((value) => value.isFinite).toList();
    if (metrics.length < minimumCount) return List<T>.of(values);

    final center = median(metrics);
    final deviation = mad(metrics);
    if (deviation <= 1e-12) return List<T>.of(values);
    final robustScale = 1.4826 * deviation;

    final filtered = values.where((value) {
      final metric = selector(value);
      if (!metric.isFinite) return false;
      return ((metric - center).abs() / robustScale) <= zLimit;
    }).toList();

    return filtered.length >= 3 ? filtered : List<T>.of(values);
  }

  static T weightedRepresentative<T>({
    required List<T> values,
    required double Function(T value) metric,
    required double Function(T value) absorption,
    required double targetAbsorption,
    required double probability,
  }) {
    if (values.isEmpty) {
      throw StateError('No hay datos históricos para seleccionar.');
    }

    final absorptionValues = values.map(absorption).toList();
    final bandwidth = math.max(1.5, math.max(0.75, iqr(absorptionValues) * 0.5));

    final weighted = values.map((value) {
      final distance = (absorption(value) - targetAbsorption) / bandwidth;
      final weight = math.exp(-0.5 * distance * distance) + 0.02;
      return (value: value, metric: metric(value), weight: weight);
    }).toList()
      ..sort((a, b) => a.metric.compareTo(b.metric));

    final totalWeight = weighted.fold<double>(
      0,
      (total, item) => total + item.weight,
    );
    final targetWeight = totalWeight * probability.clamp(0.0, 1.0).toDouble();
    var accumulated = 0.0;
    for (final item in weighted) {
      accumulated += item.weight;
      if (accumulated >= targetWeight) return item.value;
    }
    return weighted.last.value;
  }
}

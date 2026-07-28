class ModelNormalizer {
  const ModelNormalizer._();

  static String canonicalize(String? raw) {
    if (raw == null) return '';
    var value = raw.trim().toUpperCase();
    if (value.isEmpty) return '';

    const replacements = <String, String>{
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };
    replacements.forEach((from, to) => value = value.replaceAll(from, to));

    value = value
        .replaceAll(RegExp(r'[\s_/\\]+'), '-')
        .replaceAll(RegExp(r'[^A-Z0-9-]+'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll('DIVISORIO', 'DIV')
        .replaceAll('ESTRUCTURAL', 'EST');

    if (value.endsWith('DIP')) {
      value = '${value.substring(0, value.length - 3)}DIV';
    }

    value = value.replaceAllMapped(
      RegExp(r'^([A-Z]+\d+[A-Z]?)(DIV|EST)$'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    return value.replaceAll(RegExp(r'-+'), '-').replaceAll(
          RegExp(r'^-|-$'),
          '',
        );
  }

  static String chooseFlexureModel({
    String? routeModel,
    String? sampleId,
    String? itemCode,
    String? material,
  }) {
    final fromRoute = canonicalize(routeModel);
    if (fromRoute.isNotEmpty) return fromRoute;

    var candidate = canonicalize(sampleId);
    if (candidate.isEmpty) candidate = canonicalize(itemCode);
    if (candidate.isEmpty) candidate = canonicalize(material);

    final datedSuffix = RegExp(r'^([A-Z]+\d+(?:-[A-Z]+)*)-\d{4}$');
    final match = datedSuffix.firstMatch(candidate);
    if (match != null) return match.group(1)!;
    return candidate;
  }

  static String chooseCompressionModel({
    String? routeModel,
    String? specimenMaterial,
    String? rowMaterial,
    String? sampleId,
  }) {
    for (final candidate in <String?>[
      routeModel,
      specimenMaterial,
      rowMaterial,
      sampleId,
    ]) {
      final normalized = canonicalize(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }
}

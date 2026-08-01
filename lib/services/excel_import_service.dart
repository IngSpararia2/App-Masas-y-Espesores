import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/model_normalizer.dart';
import '../core/models.dart';
import '../core/statistics.dart';
import '../data/database_service.dart';
import 'xlsx_table_reader.dart';

class ExcelImportService {
  const ExcelImportService._();

  static Map<String, Object?> importWorkbook({
    required Uint8List bytes,
    required String fileName,
    required String databasePath,
  }) {
    final fileHash = sha256.convert(bytes).toString();
    final db = sqlite3.open(databasePath);
    DatabaseService.configure(db);
    DatabaseService.ensureSchema(db);

    try {
      final previous = db.select(
        'SELECT source_type FROM import_batches WHERE file_hash = ? LIMIT 1;',
        [fileHash],
      );
      if (previous.isNotEmpty) {
        return <String, Object?>{
          'fileName': fileName,
          'detectedType': previous.first['source_type'] as String,
          'totalSpecimens': 0,
          'inserted': 0,
          'updated': 0,
          'unchanged': 0,
          'rejected': 0,
          'validForPrediction': 0,
          'alreadyImported': true,
          'notes': <String>[
            'El contenido exacto de este archivo ya fue importado.',
          ],
        };
      }

      final workbook = XlsxTableReader.read(bytes);
      final rows = workbook.rows;
      if (rows.isEmpty) {
        throw const FormatException('La hoja seleccionada está vacía.');
      }

      final headers = rows.first
          .map((cell) => _text(cell) ?? '')
          .toList(growable: false);
      final index = _HeaderIndex(headers);
      final type = _detectType(index);

      final parsed = switch (type) {
        MeasurementType.compression => _parseCompression(
          rows: rows,
          index: index,
          fileName: fileName,
        ),
        MeasurementType.flexure => _parseFlexure(
          rows: rows,
          index: index,
          fileName: fileName,
        ),
      };

      final normalized = _normalizeMassUnits(parsed, type);
      final prepared = normalized.map(_prepareRecord).toList(growable: false);
      final notes = <String>[];
      if (workbook.errorCellCount > 0) {
        notes.add(
          'Se omitieron ${workbook.errorCellCount} celdas con errores de Excel '
          '(por ejemplo #DIV/0! o #VALUE!).',
        );
      }
      if (workbook.ignoredCellCount > 0) {
        notes.add(
          'Se ignoraron ${workbook.ignoredCellCount} celdas mal formadas o no legibles.',
        );
      }
      if (type == MeasurementType.flexure &&
          prepared.any(
            (record) => record.flags.contains(
              'columnas_densidad_absorcion_intercambiadas',
            ),
          )) {
        notes.add(
          'Se detectaron columnas de densidad y absorción intercambiadas; '
          'ambos valores se recalcularon a partir de las masas.',
        );
      }
      if (normalized.any((record) => record.unitConverted)) {
        notes.add(
          'Se normalizaron automáticamente las unidades de masa del archivo.',
        );
      }

      var inserted = 0;
      var updated = 0;
      var unchanged = 0;
      var rejected = 0;
      var validForPrediction = 0;
      final now = DateTime.now().toUtc().toIso8601String();

      final selectExisting = db.prepare(
        'SELECT id, content_hash FROM measurements WHERE dedupe_key = ? LIMIT 1;',
      );
      final insertMeasurement = db.prepare('''
        INSERT INTO measurements (
          source_type, dedupe_key, content_hash, source_file,
          source_relative_path, source_row, specimen_index,
          model_code, raw_model, test_date, report_or_test,
          sample_id, item_code, saturated_mass, immersed_mass,
          dry_mass, natural_mass, absorption, density,
          thickness_mm, width_mm, length_mm,
          valid_for_prediction, quality_flags, imported_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        );
      ''');
      final updateMeasurement = db.prepare('''
        UPDATE measurements SET
          content_hash = ?, source_file = ?, source_relative_path = ?,
          source_row = ?, specimen_index = ?, model_code = ?, raw_model = ?,
          test_date = ?, report_or_test = ?, sample_id = ?, item_code = ?,
          saturated_mass = ?, immersed_mass = ?, dry_mass = ?, natural_mass = ?,
          absorption = ?, density = ?, thickness_mm = ?, width_mm = ?, length_mm = ?,
          valid_for_prediction = ?, quality_flags = ?, updated_at = ?
        WHERE id = ?;
      ''');

      db.execute('BEGIN IMMEDIATE;');
      try {
        for (final record in prepared) {
          if (!record.hasMinimumMassData || record.modelCode.isEmpty) {
            rejected++;
            continue;
          }
          if (record.validForPrediction) validForPrediction++;

          final existing = selectExisting.select([record.dedupeKey]);
          if (existing.isEmpty) {
            insertMeasurement.execute([
              record.type.databaseValue,
              record.dedupeKey,
              record.contentHash,
              record.fileName,
              record.relativePath,
              record.sourceRow,
              record.specimenIndex,
              record.modelCode,
              record.rawModel,
              record.testDate,
              record.reportOrTest,
              record.sampleId,
              record.itemCode,
              record.saturatedMass,
              record.immersedMass,
              record.dryMass,
              record.naturalMass,
              record.absorption,
              record.density,
              record.thicknessMm,
              record.widthMm,
              record.lengthMm,
              record.validForPrediction ? 1 : 0,
              record.flags.join('|'),
              now,
              now,
            ]);
            inserted++;
          } else {
            final row = existing.first;
            if (row['content_hash'] == record.contentHash) {
              unchanged++;
              continue;
            }
            updateMeasurement.execute([
              record.contentHash,
              record.fileName,
              record.relativePath,
              record.sourceRow,
              record.specimenIndex,
              record.modelCode,
              record.rawModel,
              record.testDate,
              record.reportOrTest,
              record.sampleId,
              record.itemCode,
              record.saturatedMass,
              record.immersedMass,
              record.dryMass,
              record.naturalMass,
              record.absorption,
              record.density,
              record.thicknessMm,
              record.widthMm,
              record.lengthMm,
              record.validForPrediction ? 1 : 0,
              record.flags.join('|'),
              now,
              row['id'],
            ]);
            updated++;
          }
        }

        db.execute(
          '''
          INSERT INTO import_batches (
            file_name, file_hash, source_type, total_specimens,
            inserted, updated, unchanged, rejected,
            valid_for_prediction, notes, imported_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
          [
            fileName,
            fileHash,
            type.databaseValue,
            prepared.length,
            inserted,
            updated,
            unchanged,
            rejected,
            validForPrediction,
            notes.join('|'),
            now,
          ],
        );
        db.execute('COMMIT;');
      } catch (_) {
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        selectExisting.dispose();
        insertMeasurement.dispose();
        updateMeasurement.dispose();
      }

      return <String, Object?>{
        'fileName': fileName,
        'detectedType': type.databaseValue,
        'totalSpecimens': prepared.length,
        'inserted': inserted,
        'updated': updated,
        'unchanged': unchanged,
        'rejected': rejected,
        'validForPrediction': validForPrediction,
        'alreadyImported': false,
        'notes': notes,
      };
    } finally {
      db.dispose();
    }
  }

  static MeasurementType _detectType(_HeaderIndex index) {
    if (index.has('bloque 1 masa saturada') ||
        index.has('bloque 1 masa natural')) {
      return MeasurementType.compression;
    }
    if (index.has('muestra 1 masa saturada') ||
        index.has('muestra 1 espesor del especimen')) {
      return MeasurementType.flexure;
    }
    throw const FormatException(
      'No se reconoció el formato. Debe ser un resumen de compresión o flexotracción.',
    );
  }

  static List<_DraftRecord> _parseCompression({
    required List<List<Object?>> rows,
    required _HeaderIndex index,
    required String fileName,
  }) {
    final output = <_DraftRecord>[];
    final routeModelColumn = index.firstOf(const [
      'ruta secundaria modelo',
      'modelo',
    ]);
    final rowMaterialColumn = index.firstOf(const ['material']);
    final dateColumn = index.firstOf(const ['fecha de ensayo']);
    final reportColumn = index.firstOf(const [
      'numero de informe',
      'no de informe',
    ]);
    final relativePathColumn = index.firstOf(const ['ruta relativa']);

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final routeModel = _text(_at(row, routeModelColumn));
      final rowMaterial = _text(_at(row, rowMaterialColumn));
      final testDate = _dateText(_at(row, dateColumn));
      final report = _text(_at(row, reportColumn));
      final relativePath = _text(_at(row, relativePathColumn));

      for (var specimen = 1; specimen <= 3; specimen++) {
        final prefix = 'bloque $specimen';
        final saturated = _number(
          _at(row, index.field(prefix, 'masa saturada')),
        );
        final immersed = _number(_at(row, index.field(prefix, 'masa inmersa')));
        final dry = _number(_at(row, index.field(prefix, 'masa seca')));
        final natural = _number(_at(row, index.field(prefix, 'masa natural')));
        if (<double?>[
          saturated,
          immersed,
          dry,
          natural,
        ].every((value) => value == null)) {
          continue;
        }

        final specimenMaterial = _text(
          _at(row, index.field(prefix, 'material')),
        );
        final sampleId = _text(
          _at(
            row,
            index.firstField(prefix, const ['id muestra', 'id de muestra']),
          ),
        );
        final itemCode = _text(
          _at(row, index.firstField(prefix, const ['codigo item', 'item'])),
        );
        final rawModel =
            routeModel ?? specimenMaterial ?? rowMaterial ?? sampleId;
        final model = ModelNormalizer.chooseCompressionModel(
          routeModel: routeModel,
          specimenMaterial: specimenMaterial,
          rowMaterial: rowMaterial,
          sampleId: sampleId,
        );

        output.add(
          _DraftRecord(
            type: MeasurementType.compression,
            fileName: fileName,
            sourceRow: rowIndex + 1,
            specimenIndex: specimen,
            modelCode: model,
            rawModel: rawModel,
            testDate: testDate,
            reportOrTest: report,
            sampleId: sampleId,
            itemCode: itemCode,
            relativePath: relativePath,
            saturatedMass: saturated,
            immersedMass: immersed,
            dryMass: dry,
            naturalMass: natural,
            rawAbsorption: _number(_at(row, index.field(prefix, 'absorcion'))),
            rawDensity: _number(_at(row, index.field(prefix, 'densidad'))),
            thicknessMm: _number(_at(row, index.field(prefix, 'espesor'))),
            widthMm: _number(
              _at(row, index.firstField(prefix, const ['longitud', 'ancho'])),
            ),
            lengthMm: _number(
              _at(row, index.firstField(prefix, const ['altura', 'longitud'])),
            ),
          ),
        );
      }
    }
    return output;
  }

  static List<_DraftRecord> _parseFlexure({
    required List<List<Object?>> rows,
    required _HeaderIndex index,
    required String fileName,
  }) {
    final output = <_DraftRecord>[];
    final routeModelColumn = index.firstOf(const [
      'ruta secundaria modelo',
      'modelo',
    ]);
    final rowMaterialColumn = index.firstOf(const ['material']);
    final dateColumn = index.firstOf(const ['fecha de ensayo']);
    final relativePathColumn = index.firstOf(const ['ruta relativa']);

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final routeModel = _text(_at(row, routeModelColumn));
      final rowMaterial = _text(_at(row, rowMaterialColumn));
      final testDate = _dateText(_at(row, dateColumn));
      final relativePath = _text(_at(row, relativePathColumn));

      for (var specimen = 1; specimen <= 5; specimen++) {
        final prefix = 'muestra $specimen';
        final saturated = _number(
          _at(row, index.field(prefix, 'masa saturada')),
        );
        final immersed = _number(_at(row, index.field(prefix, 'masa inmersa')));
        final dry = _number(_at(row, index.field(prefix, 'masa seca')));
        final thickness = _number(
          _at(
            row,
            index.firstField(prefix, const [
              'espesor del especimen',
              'espesor',
            ]),
          ),
        );
        if (<double?>[
          saturated,
          immersed,
          dry,
          thickness,
        ].every((value) => value == null)) {
          continue;
        }

        final sampleId = _text(
          _at(
            row,
            index.firstField(prefix, const ['id muestra', 'id de muestra']),
          ),
        );
        final itemCode = _text(
          _at(
            row,
            index.firstField(prefix, const ['item 1', 'item', 'codigo item']),
          ),
        );
        final specimenMaterial = _text(
          _at(row, index.field(prefix, 'material')),
        );
        final testNumber = _text(
          _at(
            row,
            index.firstField(prefix, const [
              'no de ensayo',
              'numero de ensayo',
            ]),
          ),
        );
        final model = ModelNormalizer.chooseFlexureModel(
          routeModel: routeModel,
          sampleId: sampleId,
          itemCode: itemCode,
          material: specimenMaterial ?? rowMaterial,
        );
        final rawModel = routeModel ?? sampleId ?? itemCode ?? specimenMaterial;

        output.add(
          _DraftRecord(
            type: MeasurementType.flexure,
            fileName: fileName,
            sourceRow: rowIndex + 1,
            specimenIndex: specimen,
            modelCode: model,
            rawModel: rawModel,
            testDate: testDate,
            reportOrTest: testNumber,
            sampleId: sampleId,
            itemCode: itemCode,
            relativePath: relativePath,
            saturatedMass: saturated,
            immersedMass: immersed,
            dryMass: dry,
            naturalMass: null,
            rawAbsorption: _number(_at(row, index.field(prefix, 'absorcion'))),
            rawDensity: _number(_at(row, index.field(prefix, 'densidad'))),
            thicknessMm: thickness,
            widthMm: _number(
              _at(
                row,
                index.firstField(prefix, const [
                  'ancho real del especimen',
                  'ancho',
                ]),
              ),
            ),
            lengthMm: _number(
              _at(
                row,
                index.firstField(prefix, const [
                  'longitud rectangulo inscrito',
                  'longitud',
                ]),
              ),
            ),
          ),
        );
      }
    }
    return output;
  }

  static List<_DraftRecord> _normalizeMassUnits(
    List<_DraftRecord> records,
    MeasurementType type,
  ) {
    final dryValues = records
        .map((record) => record.dryMass)
        .whereType<double>()
        .where((value) => value > 0 && value.isFinite)
        .toList();
    if (dryValues.isEmpty) return records;

    final medianDry = Statistics.median(dryValues);
    var multiplier = 1.0;
    if (type == MeasurementType.compression && medianDry > 100) {
      multiplier = 0.001;
    } else if (type == MeasurementType.flexure && medianDry < 100) {
      multiplier = 1000;
    }
    if (multiplier == 1) return records;
    return records
        .map((record) => record.scaleMasses(multiplier))
        .toList(growable: false);
  }

  static _PreparedRecord _prepareRecord(_DraftRecord draft) {
    final flags = <String>[];
    final saturated = draft.saturatedMass;
    final immersed = draft.immersedMass;
    final dry = draft.dryMass;
    var natural = draft.naturalMass;

    final hasMasses = saturated != null && immersed != null && dry != null;
    double? absorption;
    double? density;
    if (hasMasses) {
      final dryValue = dry!;
      final saturatedValue = saturated!;
      final immersedValue = immersed!;
      if (dryValue > 0 && saturatedValue > immersedValue) {
        absorption = ((saturatedValue - dryValue) / dryValue) * 100;
        density = (dryValue / (saturatedValue - immersedValue)) * 1000;
      }
    }

    final rawAbsorption = draft.rawAbsorption;
    final rawDensity = draft.rawDensity;
    if (rawAbsorption != null &&
        rawDensity != null &&
        rawAbsorption > 100 &&
        rawDensity >= 0 &&
        rawDensity < 100) {
      flags.add('columnas_densidad_absorcion_intercambiadas');
    }
    if (absorption != null && rawAbsorption != null) {
      final rawCandidate = rawAbsorption > 100 && (rawDensity ?? 999) < 100
          ? rawDensity
          : rawAbsorption;
      if (rawCandidate != null &&
          (rawCandidate - absorption).abs() > math.max(1.0, absorption * 0.2)) {
        flags.add('absorcion_recalculada');
      }
    }
    if (density != null && rawDensity != null) {
      final rawCandidate =
          rawAbsorption != null && rawAbsorption > 100 && rawDensity < 100
          ? rawAbsorption
          : rawDensity;
      if ((rawCandidate - density).abs() > math.max(100, density * 0.15)) {
        flags.add('densidad_recalculada');
      }
    }

    if (natural != null && dry != null && saturated != null) {
      if (natural < dry || natural > saturated * 1.05) {
        flags.add('masa_natural_fuera_de_rango');
        natural = null;
      }
    }

    final physicalOrder =
        hasMasses &&
        saturated! >= dry! &&
        immersed! >= 0 &&
        immersed! < saturated!;
    final validAbsorption =
        absorption != null &&
        absorption.isFinite &&
        absorption >= 0 &&
        absorption <= 30;
    final validDensity =
        density != null &&
        density.isFinite &&
        density >= 1200 &&
        density <= 3000;
    final validMassRange = switch (draft.type) {
      MeasurementType.compression => dry != null && dry > 0.05 && dry < 100,
      MeasurementType.flexure => dry != null && dry > 100 && dry < 100000,
    };
    final validThickness =
        draft.type == MeasurementType.compression ||
        (draft.thicknessMm != null &&
            draft.thicknessMm! >= 10 &&
            draft.thicknessMm! <= 300);

    final valid =
        physicalOrder &&
        validAbsorption &&
        validDensity &&
        validMassRange &&
        validThickness;
    if (!physicalOrder) flags.add('orden_fisico_invalido');
    if (!validAbsorption) flags.add('absorcion_fuera_de_rango');
    if (!validDensity) flags.add('densidad_fuera_de_rango');
    if (!validMassRange) flags.add('masa_fuera_de_rango');
    if (!validThickness) flags.add('espesor_fuera_de_rango');
    if (draft.unitConverted) flags.add('unidad_normalizada');

    final identityParts = <String>[
      draft.type.databaseValue,
      draft.modelCode,
      draft.testDate ?? '',
      draft.reportOrTest ?? '',
      draft.sampleId ?? '',
      draft.itemCode ?? '',
      draft.specimenIndex.toString(),
    ];
    final hasBusinessIdentity = <String?>[
      draft.reportOrTest,
      draft.sampleId,
      draft.itemCode,
    ].any((value) => value != null && value.trim().isNotEmpty);
    if (!hasBusinessIdentity) {
      identityParts
        ..add(draft.relativePath ?? '')
        ..add(draft.sourceRow.toString());
    }
    final dedupeKey = sha256
        .convert(utf8.encode(identityParts.join('|')))
        .toString();

    final contentParts = <Object?>[
      draft.modelCode,
      saturated,
      immersed,
      dry,
      natural,
      absorption,
      density,
      draft.thicknessMm,
      draft.widthMm,
      draft.lengthMm,
      valid,
    ];
    final contentHash = sha256
        .convert(utf8.encode(jsonEncode(contentParts)))
        .toString();

    return _PreparedRecord(
      type: draft.type,
      fileName: draft.fileName,
      sourceRow: draft.sourceRow,
      specimenIndex: draft.specimenIndex,
      modelCode: draft.modelCode,
      rawModel: draft.rawModel,
      testDate: draft.testDate,
      reportOrTest: draft.reportOrTest,
      sampleId: draft.sampleId,
      itemCode: draft.itemCode,
      relativePath: draft.relativePath,
      saturatedMass: saturated,
      immersedMass: immersed,
      dryMass: dry,
      naturalMass: natural,
      absorption: absorption,
      density: density,
      thicknessMm: draft.thicknessMm,
      widthMm: draft.widthMm,
      lengthMm: draft.lengthMm,
      validForPrediction: valid,
      flags: flags,
      dedupeKey: dedupeKey,
      contentHash: contentHash,
    );
  }

  static Object? _at(List<Object?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return row[index];
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static double? _number(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static String? _dateText(Object? value) {
    if (value == null) return null;
    if (value is DateTime) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }
    if (value is num && value > 20000 && value < 100000) {
      final date = DateTime(1899, 12, 30).add(Duration(days: value.floor()));
      return _dateText(date);
    }
    return _text(value);
  }
}

class _HeaderIndex {
  _HeaderIndex(List<String> headers)
    : _indices = <String, int>{
        for (var i = 0; i < headers.length; i++) _normalize(headers[i]): i,
      };

  final Map<String, int> _indices;

  bool has(String header) => _indices.containsKey(_normalize(header));

  int? firstOf(List<String> candidates) {
    for (final candidate in candidates) {
      final index = _indices[_normalize(candidate)];
      if (index != null) return index;
    }
    return null;
  }

  int? field(String prefix, String field) {
    return _indices[_normalize('$prefix $field')];
  }

  int? firstField(String prefix, List<String> fields) {
    for (final fieldName in fields) {
      final index = field(prefix, fieldName);
      if (index != null) return index;
    }
    return null;
  }

  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _DraftRecord {
  const _DraftRecord({
    required this.type,
    required this.fileName,
    required this.sourceRow,
    required this.specimenIndex,
    required this.modelCode,
    required this.rawModel,
    required this.testDate,
    required this.reportOrTest,
    required this.sampleId,
    required this.itemCode,
    required this.relativePath,
    required this.saturatedMass,
    required this.immersedMass,
    required this.dryMass,
    required this.naturalMass,
    required this.rawAbsorption,
    required this.rawDensity,
    required this.thicknessMm,
    required this.widthMm,
    required this.lengthMm,
    this.unitConverted = false,
  });

  final MeasurementType type;
  final String fileName;
  final int sourceRow;
  final int specimenIndex;
  final String modelCode;
  final String? rawModel;
  final String? testDate;
  final String? reportOrTest;
  final String? sampleId;
  final String? itemCode;
  final String? relativePath;
  final double? saturatedMass;
  final double? immersedMass;
  final double? dryMass;
  final double? naturalMass;
  final double? rawAbsorption;
  final double? rawDensity;
  final double? thicknessMm;
  final double? widthMm;
  final double? lengthMm;
  final bool unitConverted;

  _DraftRecord scaleMasses(double multiplier) {
    double? scale(double? value) => value == null ? null : value * multiplier;
    return _DraftRecord(
      type: type,
      fileName: fileName,
      sourceRow: sourceRow,
      specimenIndex: specimenIndex,
      modelCode: modelCode,
      rawModel: rawModel,
      testDate: testDate,
      reportOrTest: reportOrTest,
      sampleId: sampleId,
      itemCode: itemCode,
      relativePath: relativePath,
      saturatedMass: scale(saturatedMass),
      immersedMass: scale(immersedMass),
      dryMass: scale(dryMass),
      naturalMass: scale(naturalMass),
      rawAbsorption: rawAbsorption,
      rawDensity: rawDensity,
      thicknessMm: thicknessMm,
      widthMm: widthMm,
      lengthMm: lengthMm,
      unitConverted: true,
    );
  }
}

class _PreparedRecord {
  const _PreparedRecord({
    required this.type,
    required this.fileName,
    required this.sourceRow,
    required this.specimenIndex,
    required this.modelCode,
    required this.rawModel,
    required this.testDate,
    required this.reportOrTest,
    required this.sampleId,
    required this.itemCode,
    required this.relativePath,
    required this.saturatedMass,
    required this.immersedMass,
    required this.dryMass,
    required this.naturalMass,
    required this.absorption,
    required this.density,
    required this.thicknessMm,
    required this.widthMm,
    required this.lengthMm,
    required this.validForPrediction,
    required this.flags,
    required this.dedupeKey,
    required this.contentHash,
  });

  final MeasurementType type;
  final String fileName;
  final int sourceRow;
  final int specimenIndex;
  final String modelCode;
  final String? rawModel;
  final String? testDate;
  final String? reportOrTest;
  final String? sampleId;
  final String? itemCode;
  final String? relativePath;
  final double? saturatedMass;
  final double? immersedMass;
  final double? dryMass;
  final double? naturalMass;
  final double? absorption;
  final double? density;
  final double? thicknessMm;
  final double? widthMm;
  final double? lengthMm;
  final bool validForPrediction;
  final List<String> flags;
  final String dedupeKey;
  final String contentHash;

  bool get hasMinimumMassData =>
      saturatedMass != null &&
      immersedMass != null &&
      dryMass != null &&
      absorption != null &&
      density != null;
}

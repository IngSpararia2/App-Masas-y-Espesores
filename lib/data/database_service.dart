import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/models.dart';

class DatabaseService {
  Database? _database;
  String? _databasePath;

  String get databasePath {
    final value = _databasePath;
    if (value == null) {
      throw StateError('La base de datos no está inicializada.');
    }
    return value;
  }

  Database get _db {
    final value = _database;
    if (value == null) {
      throw StateError('La base de datos no está inicializada.');
    }
    return value;
  }

  Future<void> initialize() async {
    if (_database != null) return;
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    _databasePath = p.join(directory.path, 'masalab_historico.sqlite');
    _database = sqlite3.open(_databasePath!);
    configure(_db);
    ensureSchema(_db);
  }

  static void configure(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA busy_timeout = 8000;');
  }

  static void ensureSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_type TEXT NOT NULL,
        dedupe_key TEXT NOT NULL UNIQUE,
        content_hash TEXT NOT NULL,
        source_file TEXT NOT NULL,
        source_relative_path TEXT,
        source_row INTEGER NOT NULL,
        specimen_index INTEGER NOT NULL,
        model_code TEXT NOT NULL,
        raw_model TEXT,
        test_date TEXT,
        report_or_test TEXT,
        sample_id TEXT,
        item_code TEXT,
        saturated_mass REAL NOT NULL,
        immersed_mass REAL NOT NULL,
        dry_mass REAL NOT NULL,
        natural_mass REAL,
        absorption REAL NOT NULL,
        density REAL NOT NULL,
        thickness_mm REAL,
        width_mm REAL,
        length_mm REAL,
        valid_for_prediction INTEGER NOT NULL DEFAULT 0,
        quality_flags TEXT,
        imported_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS ix_measurements_type_model_valid
      ON measurements(source_type, model_code, valid_for_prediction);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS ix_measurements_date
      ON measurements(test_date);
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS import_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        file_hash TEXT NOT NULL UNIQUE,
        source_type TEXT NOT NULL,
        total_specimens INTEGER NOT NULL,
        inserted INTEGER NOT NULL,
        updated INTEGER NOT NULL,
        unchanged INTEGER NOT NULL,
        rejected INTEGER NOT NULL,
        valid_for_prediction INTEGER NOT NULL,
        notes TEXT,
        imported_at TEXT NOT NULL
      );
    ''');
  }

  Future<AppStats> getStats() async {
    final totalRow = _db.select('''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(valid_for_prediction), 0) AS valid
      FROM measurements;
    ''').first;

    final modelRows = _db.select('''
      SELECT source_type, COUNT(DISTINCT model_code) AS models
      FROM measurements
      WHERE valid_for_prediction = 1
      GROUP BY source_type;
    ''');

    var compressionModels = 0;
    var flexureModels = 0;
    for (final row in modelRows) {
      final type = row['source_type'] as String;
      final count = (row['models'] as num).toInt();
      if (type == MeasurementType.compression.databaseValue) {
        compressionModels = count;
      } else if (type == MeasurementType.flexure.databaseValue) {
        flexureModels = count;
      }
    }

    final batchCount =
        (_db
                    .select('SELECT COUNT(*) AS count FROM import_batches;')
                    .first['count']
                as num)
            .toInt();

    return AppStats(
      totalMeasurements: (totalRow['total'] as num).toInt(),
      validMeasurements: (totalRow['valid'] as num).toInt(),
      compressionModels: compressionModels,
      flexureModels: flexureModels,
      importBatches: batchCount,
    );
  }

  Future<List<ModelSummary>> getModelSummaries(MeasurementType type) async {
    final rows = _db.select(
      '''
      SELECT
        model_code,
        COUNT(*) AS total_samples,
        COALESCE(SUM(valid_for_prediction), 0) AS valid_samples,
        MIN(CASE WHEN valid_for_prediction = 1 THEN absorption END) AS min_abs,
        MAX(CASE WHEN valid_for_prediction = 1 THEN absorption END) AS max_abs,
        MIN(CASE WHEN valid_for_prediction = 1 THEN thickness_mm END) AS min_thickness,
        MAX(CASE WHEN valid_for_prediction = 1 THEN thickness_mm END) AS max_thickness
      FROM measurements
      WHERE source_type = ?
      GROUP BY model_code
      HAVING COALESCE(SUM(valid_for_prediction), 0) > 0
      ORDER BY model_code COLLATE NOCASE;
    ''',
      [type.databaseValue],
    );

    return rows
        .map((row) {
          return ModelSummary(
            type: type,
            modelCode: row['model_code'] as String,
            totalSamples: (row['total_samples'] as num).toInt(),
            validSamples: (row['valid_samples'] as num).toInt(),
            minAbsorption: (row['min_abs'] as num).toDouble(),
            maxAbsorption: (row['max_abs'] as num).toDouble(),
            minThicknessMm: (row['min_thickness'] as num?)?.toDouble(),
            maxThicknessMm: (row['max_thickness'] as num?)?.toDouble(),
          );
        })
        .toList(growable: false);
  }

  Future<List<HistoricalSample>> getSamples(
    MeasurementType type,
    String modelCode,
  ) async {
    final rows = _db.select(
      '''
      SELECT
        dry_mass,
        saturated_mass,
        immersed_mass,
        natural_mass,
        absorption,
        density,
        thickness_mm
      FROM measurements
      WHERE source_type = ?
        AND model_code = ?
        AND valid_for_prediction = 1;
    ''',
      [type.databaseValue, modelCode],
    );

    return rows
        .map((row) {
          return HistoricalSample(
            type: type,
            modelCode: modelCode,
            dryMass: (row['dry_mass'] as num).toDouble(),
            saturatedMass: (row['saturated_mass'] as num).toDouble(),
            immersedMass: (row['immersed_mass'] as num).toDouble(),
            naturalMass: (row['natural_mass'] as num?)?.toDouble(),
            absorption: (row['absorption'] as num).toDouble(),
            density: (row['density'] as num).toDouble(),
            thicknessMm: (row['thickness_mm'] as num?)?.toDouble(),
          );
        })
        .toList(growable: false);
  }

  Future<List<ImportBatch>> getRecentImports({int limit = 12}) async {
    final rows = _db.select(
      '''
      SELECT id, file_name, source_type, imported_at,
             inserted, updated, unchanged, rejected
      FROM import_batches
      ORDER BY id DESC
      LIMIT ?;
    ''',
      [limit],
    );

    return rows
        .map((row) {
          return ImportBatch(
            id: (row['id'] as num).toInt(),
            fileName: row['file_name'] as String,
            type: MeasurementTypeLabel.fromDatabase(
              row['source_type'] as String,
            ),
            importedAt: DateTime.parse(row['imported_at'] as String).toLocal(),
            inserted: (row['inserted'] as num).toInt(),
            updated: (row['updated'] as num).toInt(),
            unchanged: (row['unchanged'] as num).toInt(),
            rejected: (row['rejected'] as num).toInt(),
          );
        })
        .toList(growable: false);
  }

  Future<void> clearAllData() async {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      _db.execute('DELETE FROM measurements;');
      _db.execute('DELETE FROM import_batches;');
      _db.execute(
        'DELETE FROM sqlite_sequence WHERE name IN '
        "('measurements', 'import_batches');",
      );
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<File> createBackup() async {
    final source = File(databasePath);
    if (!await source.exists()) {
      throw StateError('No existe la base de datos para respaldar.');
    }
    final downloads = await getDownloadsDirectory();
    final destinationDirectory =
        downloads ?? await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final destination = File(
      p.join(destinationDirectory.path, 'masalab_backup_$timestamp.sqlite'),
    );
    if (await destination.exists()) await destination.delete();
    final escapedPath = destination.path.replaceAll("'", "''");
    _db.execute("VACUUM INTO '$escapedPath';");
    return destination;
  }

  void dispose() {
    _database?.close();
    _database = null;
  }
}

import 'dart:isolate';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../data/database_service.dart';
import 'excel_import_service.dart';
import 'prediction_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    DatabaseService? database,
    PredictionService? predictionService,
  }) : _database = database ?? DatabaseService(),
       _predictionService = predictionService ?? const PredictionService();

  final DatabaseService _database;
  final PredictionService _predictionService;

  bool initializing = true;
  bool importing = false;
  bool backingUp = false;
  String? errorMessage;
  String? informationMessage;
  AppStats stats = AppStats.empty;
  List<ModelSummary> compressionModels = const [];
  List<ModelSummary> flexureModels = const [];
  List<ImportBatch> recentImports = const [];
  List<ImportSummary> lastImportResults = const [];
  PredictionResult? lastPrediction;

  String get databasePath => _database.databasePath;

  List<ModelSummary> modelsFor(MeasurementType type) => switch (type) {
    MeasurementType.compression => compressionModels,
    MeasurementType.flexure => flexureModels,
  };

  Future<void> initialize() async {
    initializing = true;
    notifyListeners();
    try {
      await _database.initialize();
      await refresh();
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    stats = await _database.getStats();
    compressionModels = (await _database.getModelSummaries(
      MeasurementType.compression,
    )).where((model) => model.canPredict).toList(growable: false);
    flexureModels = (await _database.getModelSummaries(
      MeasurementType.flexure,
    )).where((model) => model.canPredict).toList(growable: false);
    recentImports = await _database.getRecentImports();
    notifyListeners();
  }

  Future<void> pickAndImportFiles() async {
    clearMessages();
    try {
      const excelFiles = XTypeGroup(
        label: 'Archivos de Excel',
        extensions: <String>['xlsx'],
        mimeTypes: <String>[
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      );
      final files = await openFiles(
        acceptedTypeGroups: const <XTypeGroup>[excelFiles],
      );
      if (files.isEmpty) return;

      final payloads = <ImportPayload>[];
      for (final file in files) {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('No se pudo leer ${file.name}.');
        }
        payloads.add(ImportPayload(fileName: file.name, bytes: bytes));
      }
      await importPayloads(payloads);
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
    }
  }

  Future<void> importPayloads(List<ImportPayload> payloads) async {
    if (payloads.isEmpty || importing) return;
    importing = true;
    lastImportResults = const [];
    errorMessage = null;
    informationMessage = null;
    notifyListeners();

    final results = <ImportSummary>[];
    try {
      for (final payload in payloads) {
        final fileName = payload.fileName;
        final bytes = payload.bytes;
        final dbPath = databasePath;
        final rawResult = await Isolate.run<Map<String, Object?>>(
          () => ExcelImportService.importWorkbook(
            bytes: bytes,
            fileName: fileName,
            databasePath: dbPath,
          ),
        );
        results.add(ImportSummary.fromMap(rawResult));
      }
      lastImportResults = results;
      await refresh();
      informationMessage = 'Importación terminada correctamente.';
    } catch (error) {
      lastImportResults = results;
      errorMessage = _friendlyError(error);
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  Future<PredictionResult> calculate({
    required MeasurementType type,
    required String modelCode,
    required double absorption,
    double? thicknessMm,
  }) async {
    clearMessages();
    final samples = await _database.getSamples(type, modelCode);
    final result = _predictionService.predict(
      type: type,
      modelCode: modelCode,
      sourceSamples: samples,
      targetAbsorption: absorption,
      targetThicknessMm: thicknessMm,
    );
    lastPrediction = result;
    notifyListeners();
    return result;
  }

  Future<List<PredictionResult>> calculateLaboratoryTrials({
    required MeasurementType type,
    required String modelCode,
    required List<LaboratoryTrialTarget> targets,
  }) async {
    if (targets.isEmpty) {
      throw ArgumentError('Ingrese al menos un elemento para calcular.');
    }

    clearMessages();
    final samples = await _database.getSamples(type, modelCode);
    final results = targets
        .map(
          (target) => _predictionService.predict(
            type: type,
            modelCode: modelCode,
            sourceSamples: samples,
            targetAbsorption: target.absorption,
            targetThicknessMm: target.thicknessMm,
          ),
        )
        .toList(growable: false);
    notifyListeners();
    return results;
  }

  Future<String> createBackup() async {
    backingUp = true;
    clearMessages();
    notifyListeners();
    try {
      final file = await _database.createBackup();
      informationMessage = 'Respaldo creado en ${file.path}';
      return file.path;
    } catch (error) {
      errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      backingUp = false;
      notifyListeners();
    }
  }

  Future<void> clearDatabase() async {
    clearMessages();
    await _database.clearAllData();
    lastPrediction = null;
    lastImportResults = const [];
    await refresh();
    informationMessage = 'La base de datos fue reiniciada.';
    notifyListeners();
  }

  void clearPrediction() {
    lastPrediction = null;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    informationMessage = null;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _database.dispose();
    super.dispose();
  }
}

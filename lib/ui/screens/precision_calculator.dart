import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../services/app_controller.dart';

class PrecisionCalculator extends StatefulWidget {
  const PrecisionCalculator({super.key, required this.controller});

  final AppController controller;

  @override
  State<PrecisionCalculator> createState() => _PrecisionCalculatorState();
}

class _PrecisionCalculatorState extends State<PrecisionCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _absorptionController = TextEditingController(text: '6.0');
  final _thicknessController = TextEditingController(text: '80');
  MeasurementType _type = MeasurementType.compression;
  String? _modelCode;
  bool _calculating = false;
  String? _localError;

  @override
  void dispose() {
    _absorptionController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.controller.modelsFor(_type);
    if (_modelCode != null &&
        !models.any((model) => model.modelCode == _modelCode)) {
      _modelCode = null;
    }
    final selectedSummary = _modelCode == null
        ? null
        : models.where((model) => model.modelCode == _modelCode).firstOrNull;
    final prediction = widget.controller.lastPrediction;
    final visiblePrediction =
        prediction != null &&
            prediction.type == _type &&
            prediction.modelCode == _modelCode
        ? prediction
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Estimación de masas',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Seleccione un modelo del histórico y defina las condiciones del cálculo.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<MeasurementType>(
                          segments: const [
                            ButtonSegment(
                              value: MeasurementType.compression,
                              icon: Icon(Icons.view_in_ar_outlined),
                              label: Text('Compresión'),
                            ),
                            ButtonSegment(
                              value: MeasurementType.flexure,
                              icon: Icon(Icons.horizontal_rule_rounded),
                              label: Text('Flexotracción'),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _type = selection.first;
                              _modelCode = null;
                              _localError = null;
                            });
                            widget.controller.clearPrediction();
                          },
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'precision-model-${_type.databaseValue}-${_modelCode ?? 'empty'}',
                          ),
                          initialValue: _modelCode,
                          decoration: const InputDecoration(
                            labelText: 'Modelo del elemento',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          isExpanded: true,
                          hint: Text(
                            models.isEmpty
                                ? 'Importe primero un histórico'
                                : 'Seleccione un modelo',
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: models
                              .map(
                                (model) => DropdownMenuItem(
                                  value: model.modelCode,
                                  child: Text(
                                    '${model.modelCode}  ·  ${model.validSamples} datos',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: models.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _modelCode = value;
                                    _localError = null;
                                  });
                                  widget.controller.clearPrediction();
                                },
                          validator: (value) =>
                              value == null ? 'Seleccione un modelo.' : null,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 600;
                            final fields = <Widget>[
                              TextFormField(
                                controller: _absorptionController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Absorción objetivo',
                                  suffixText: '%',
                                  prefixIcon: Icon(Icons.water_drop_outlined),
                                ),
                                validator: (value) {
                                  final number = parseCalculatorNumber(value);
                                  if (number == null ||
                                      number < 0 ||
                                      number > 30) {
                                    return 'Use un valor entre 0 y 30.';
                                  }
                                  return null;
                                },
                              ),
                              if (_type == MeasurementType.flexure)
                                TextFormField(
                                  controller: _thicknessController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Espesor objetivo',
                                    suffixText: 'mm',
                                    prefixIcon: Icon(Icons.height),
                                  ),
                                  validator: (value) {
                                    final number = parseCalculatorNumber(value);
                                    if (number == null ||
                                        number < 10 ||
                                        number > 300) {
                                      return 'Use un valor entre 10 y 300 mm.';
                                    }
                                    return null;
                                  },
                                ),
                            ];
                            if (!isWide || fields.length == 1) {
                              return Column(
                                children: [
                                  for (var i = 0; i < fields.length; i++) ...[
                                    fields[i],
                                    if (i < fields.length - 1)
                                      const SizedBox(height: 14),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 14),
                                Expanded(child: fields[1]),
                              ],
                            );
                          },
                        ),
                        if (selectedSummary != null) ...[
                          const SizedBox(height: 14),
                          HistoricalRange(summary: selectedSummary),
                        ],
                        if (_localError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _localError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _calculating ? null : _calculate,
                          icon: _calculating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.calculate_outlined),
                          label: Text(
                            _calculating
                                ? 'Calculando…'
                                : 'Calcular escenarios',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (visiblePrediction != null)
                _PredictionPanel(result: visiblePrediction)
              else if (models.isEmpty)
                const EmptyCalculatorState(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _calculating = true;
      _localError = null;
    });
    try {
      await widget.controller.calculate(
        type: _type,
        modelCode: _modelCode!,
        absorption: parseCalculatorNumber(_absorptionController.text)!,
        thicknessMm: _type == MeasurementType.flexure
            ? parseCalculatorNumber(_thicknessController.text)
            : null,
      );
    } catch (error) {
      setState(() {
        _localError = friendlyCalculatorError(error);
      });
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }
}

class HistoricalRange extends StatelessWidget {
  const HistoricalRange({super.key, required this.summary});

  final ModelSummary summary;

  @override
  Widget build(BuildContext context) {
    final thickness = summary.minThicknessMm == null
        ? null
        : '${summary.minThicknessMm!.toStringAsFixed(1)}–'
              '${summary.maxThicknessMm!.toStringAsFixed(1)} mm';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          MiniFact(
            label: 'Muestras válidas',
            value: summary.validSamples.toString(),
          ),
          MiniFact(
            label: 'Absorción histórica',
            value:
                '${summary.minAbsorption.toStringAsFixed(2)}–'
                '${summary.maxAbsorption.toStringAsFixed(2)} %',
          ),
          if (thickness != null)
            MiniFact(label: 'Espesor histórico', value: thickness),
        ],
      ),
    );
  }
}

class MiniFact extends StatelessWidget {
  const MiniFact({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _PredictionPanel extends StatelessWidget {
  const _PredictionPanel({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resultados para ${result.modelCode}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Chip(
              avatar: const Icon(Icons.verified_outlined, size: 18),
              label: Text('Confianza ${result.confidence.toLowerCase()}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${result.sampleCount} datos históricos después del filtrado estadístico.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 850
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth >= 560
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final scenario in result.scenarios)
                  SizedBox(
                    width: width,
                    child: _ScenarioCard(
                      result: result,
                      scenario: scenario,
                      highlighted: scenario.label == 'Típico',
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Criterio matemático',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  result.type == MeasurementType.flexure
                      ? 'Se seleccionan especímenes históricos ponderados por cercanía de absorción. '
                            'La masa seca se escala con la relación masa seca/espesor del mismo modelo. '
                            'Luego: Msat = Mseca × (1 + A/100) y '
                            'Msumergida = Msat − Mseca × 1000/ρ.'
                      : 'Se seleccionan especímenes históricos ponderados por cercanía de absorción '
                            'en los percentiles 15, 50 y 85. Luego: '
                            'Msat = Mseca × (1 + A/100) y '
                            'Msumergida = Msat − Mseca × 1000/ρ.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.result,
    required this.scenario,
    required this.highlighted,
  });

  final PredictionResult result;
  final MassScenario scenario;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final unit = result.type.massUnit;
    return Card(
      color: highlighted
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text('P${(scenario.quantile * 100).round()}'),
              ],
            ),
            const SizedBox(height: 12),
            MassLine(
              label: 'Masa saturada',
              value: formatMass(scenario.saturatedMass, result.type),
              unit: unit,
            ),
            if (result.type == MeasurementType.flexure)
              MassLine(
                label: 'Masa seca',
                value: formatMass(scenario.dryMass, result.type),
                unit: unit,
              ),
            MassLine(
              label: 'Masa inmersa',
              value: formatMass(scenario.immersedMass, result.type),
              unit: unit,
            ),
            if (result.type == MeasurementType.compression)
              MassLine(
                label: 'Masa seca',
                value: formatMass(scenario.dryMass, result.type),
                unit: unit,
              ),
            if (scenario.naturalMass != null)
              MassLine(
                label: 'Masa natural',
                value: formatMass(scenario.naturalMass!, result.type),
                unit: unit,
              ),
            const Divider(height: 20),
            Text(
              'Densidad usada: ${scenario.density.toStringAsFixed(0)} kg/m³',
            ),
          ],
        ),
      ),
    );
  }
}

class MassLine extends StatelessWidget {
  const MassLine({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class EmptyCalculatorState extends StatelessWidget {
  const EmptyCalculatorState({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay modelos disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Abra la pestaña Importar y seleccione uno o ambos archivos de resumen en formato XLSX.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

double? parseCalculatorNumber(String? value) {
  if (value == null) return null;
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

String friendlyCalculatorError(Object error) {
  return error
      .toString()
      .replaceFirst('ArgumentError: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}

String formatMass(double value, MeasurementType type) {
  return type == MeasurementType.compression
      ? value.toStringAsFixed(3)
      : value.toStringAsFixed(0);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

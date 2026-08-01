import 'package:flutter/material.dart';

import '../../core/laboratory_randomizer.dart';
import '../../core/models.dart';
import '../../services/app_controller.dart';
import 'precision_calculator.dart';

const _baseElementCount = 5;
const _counterSampleCount = 3;
const _totalFieldCount = _baseElementCount + _counterSampleCount;

class LaboratoryTrialsCalculator extends StatefulWidget {
  const LaboratoryTrialsCalculator({
    super.key,
    required this.controller,
    this.randomizer,
  });

  final AppController controller;
  final LaboratoryRandomizer? randomizer;

  @override
  State<LaboratoryTrialsCalculator> createState() =>
      _LaboratoryTrialsCalculatorState();
}

class _LaboratoryTrialsCalculatorState
    extends State<LaboratoryTrialsCalculator> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _absorptionControllers;
  late final List<TextEditingController> _thicknessControllers;
  late final LaboratoryRandomizer _randomizer;

  MeasurementType _type = MeasurementType.flexure;
  String? _modelCode;
  bool _testCounterSamples = false;
  bool _calculating = false;
  RangeValues? _absorptionRange;
  RangeValues? _thicknessRange;
  String? _localError;
  List<_DisplayedTrialResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _randomizer = widget.randomizer ?? LaboratoryRandomizer();
    _absorptionControllers = List.generate(
      _totalFieldCount,
      (_) => TextEditingController(),
    );
    _thicknessControllers = List.generate(
      _totalFieldCount,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _absorptionControllers) {
      controller.dispose();
    }
    for (final controller in _thicknessControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.controller.modelsFor(_type);
    if (_modelCode != null &&
        !models.any((model) => model.modelCode == _modelCode)) {
      _modelCode = null;
      _absorptionRange = null;
      _thicknessRange = null;
      _results = const [];
    }
    final selectedSummary = _modelCode == null
        ? null
        : models.where((model) => model.modelCode == _modelCode).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Apoyo para ensayos de laboratorio',
                key: const ValueKey('laboratory-trials-title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prepare los valores de cada elemento y calcule una estimación típica para apoyar el ensayo.',
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
                          key: const ValueKey('trial-type-selector'),
                          segments: const [
                            ButtonSegment(
                              value: MeasurementType.flexure,
                              icon: Icon(Icons.horizontal_rule_rounded),
                              label: Text('Flexotracción'),
                            ),
                            ButtonSegment(
                              value: MeasurementType.compression,
                              icon: Icon(Icons.view_in_ar_outlined),
                              label: Text('Compresión'),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) {
                            _changeType(selection.first);
                          },
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'trial-model-${_type.databaseValue}-${_modelCode ?? 'empty'}',
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
                              : (value) => _selectModel(value, models),
                          validator: (value) =>
                              value == null ? 'Seleccione un modelo.' : null,
                        ),
                        if (selectedSummary != null) ...[
                          const SizedBox(height: 14),
                          HistoricalRange(summary: selectedSummary),
                        ],
                        const SizedBox(height: 22),
                        Text(
                          'Elementos principales',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _type == MeasurementType.flexure
                              ? 'Ingrese cinco absorciones y cinco espesores.'
                              : 'Ingrese las absorciones de los cinco elementos.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < _baseElementCount;
                          index++
                        ) ...[
                          _SpecimenFields(
                            key: ValueKey('trial-element-${index + 1}'),
                            label: 'Elemento ${index + 1}',
                            absorptionController: _absorptionControllers[index],
                            thicknessController: _thicknessControllers[index],
                            showThickness: _type == MeasurementType.flexure,
                            absorptionValidator: (value) =>
                                _validateAbsorption(index, value),
                            thicknessValidator: (value) =>
                                _validateThickness(index, value),
                            onChanged: _clearResultsAfterEdit,
                          ),
                          if (index < _baseElementCount - 1)
                            const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          key: const ValueKey('counter-samples-checkbox'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Ensayar contra-muestras'),
                          subtitle: const Text(
                            'Puede diligenciar una, dos o las tres contra-muestras.',
                          ),
                          value: _testCounterSamples,
                          onChanged: (value) {
                            setState(() {
                              _testCounterSamples = value ?? false;
                              _results = const [];
                              _localError = null;
                            });
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.topCenter,
                          child: !_testCounterSamples
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 4),
                                    for (
                                      var counterIndex = 0;
                                      counterIndex < _counterSampleCount;
                                      counterIndex++
                                    ) ...[
                                      Builder(
                                        builder: (context) {
                                          final fieldIndex =
                                              _baseElementCount + counterIndex;
                                          return _SpecimenFields(
                                            key: ValueKey(
                                              'trial-counter-${counterIndex + 1}',
                                            ),
                                            label:
                                                'Contra-muestra ${counterIndex + 1}',
                                            optional: true,
                                            absorptionController:
                                                _absorptionControllers[fieldIndex],
                                            thicknessController:
                                                _thicknessControllers[fieldIndex],
                                            showThickness:
                                                _type ==
                                                MeasurementType.flexure,
                                            absorptionValidator: (value) =>
                                                _validateAbsorption(
                                                  fieldIndex,
                                                  value,
                                                ),
                                            thicknessValidator: (value) =>
                                                _validateThickness(
                                                  fieldIndex,
                                                  value,
                                                ),
                                            onChanged: _clearResultsAfterEdit,
                                          );
                                        },
                                      ),
                                      if (counterIndex <
                                          _counterSampleCount - 1)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            key: ValueKey(
                              'random-configuration-${_modelCode ?? 'empty'}',
                            ),
                            enabled: selectedSummary != null,
                            leading: const Icon(Icons.shuffle_rounded),
                            title: const Text('Configuración de aleatoriedad'),
                            subtitle: Text(
                              selectedSummary == null
                                  ? 'Seleccione primero un modelo.'
                                  : 'Ajuste los límites inferior y superior.',
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            children: [
                              if (selectedSummary != null) ...[
                                _RangeSetting(
                                  key: const ValueKey('absorption-range'),
                                  title: 'Absorción',
                                  unit: '%',
                                  minimum: selectedSummary.minAbsorption,
                                  maximum: selectedSummary.maxAbsorption,
                                  values:
                                      _absorptionRange ??
                                      RangeValues(
                                        selectedSummary.minAbsorption,
                                        selectedSummary.maxAbsorption,
                                      ),
                                  onChanged: (values) {
                                    setState(() {
                                      _absorptionRange = values;
                                      _results = const [];
                                    });
                                  },
                                ),
                                if (_type == MeasurementType.flexure &&
                                    selectedSummary.minThicknessMm != null &&
                                    selectedSummary.maxThicknessMm != null)
                                  _RangeSetting(
                                    key: const ValueKey('thickness-range'),
                                    title: 'Espesor',
                                    unit: 'mm',
                                    minimum: selectedSummary.minThicknessMm!,
                                    maximum: selectedSummary.maxThicknessMm!,
                                    values:
                                        _thicknessRange ??
                                        RangeValues(
                                          selectedSummary.minThicknessMm!,
                                          selectedSummary.maxThicknessMm!,
                                        ),
                                    onChanged: (values) {
                                      setState(() {
                                        _thicknessRange = values;
                                        _results = const [];
                                      });
                                    },
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final absorptionButton = FilledButton.tonalIcon(
                              key: const ValueKey('random-absorptions-button'),
                              onPressed: _absorptionRange == null
                                  ? null
                                  : _generateAbsorptions,
                              icon: const Icon(Icons.water_drop_outlined),
                              label: const Text('Absorciones aleatorias'),
                            );
                            final thicknessButton = FilledButton.tonalIcon(
                              key: const ValueKey('random-thicknesses-button'),
                              onPressed: _thicknessRange == null
                                  ? null
                                  : _generateThicknesses,
                              icon: const Icon(Icons.height),
                              label: const Text('Espesores aleatorios'),
                            );
                            if (_type == MeasurementType.compression) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: absorptionButton,
                              );
                            }
                            if (constraints.maxWidth < 560) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  absorptionButton,
                                  const SizedBox(height: 10),
                                  thicknessButton,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: absorptionButton),
                                const SizedBox(width: 12),
                                Expanded(child: thicknessButton),
                              ],
                            );
                          },
                        ),
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
                          key: const ValueKey('calculate-trials-button'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
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
                            _calculating ? 'Calculando…' : 'Calcular',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_results.isNotEmpty)
                _TrialResultsPanel(type: _type, results: _results)
              else if (models.isEmpty)
                const EmptyCalculatorState(),
            ],
          ),
        ),
      ),
    );
  }

  void _changeType(MeasurementType type) {
    setState(() {
      _type = type;
      _modelCode = null;
      _absorptionRange = null;
      _thicknessRange = null;
      _localError = null;
      _results = const [];
      _clearAllFields();
    });
  }

  void _selectModel(String? value, List<ModelSummary> models) {
    final summary = value == null
        ? null
        : models.where((model) => model.modelCode == value).firstOrNull;
    setState(() {
      _modelCode = value;
      _localError = null;
      _results = const [];
      _absorptionRange = summary == null
          ? null
          : RangeValues(summary.minAbsorption, summary.maxAbsorption);
      _thicknessRange =
          summary?.minThicknessMm == null || summary?.maxThicknessMm == null
          ? null
          : RangeValues(summary!.minThicknessMm!, summary.maxThicknessMm!);
    });
  }

  void _generateAbsorptions() {
    final range = _absorptionRange;
    if (range == null) return;
    setState(() {
      for (var index = 0; index < _visibleFieldCount; index++) {
        _absorptionControllers[index].text = _randomizer
            .nextHundredth(min: range.start, max: range.end)
            .toStringAsFixed(2);
      }
      _results = const [];
      _localError = null;
    });
  }

  void _generateThicknesses() {
    final range = _thicknessRange;
    if (range == null || _type != MeasurementType.flexure) return;
    setState(() {
      for (var index = 0; index < _visibleFieldCount; index++) {
        _thicknessControllers[index].text = _randomizer
            .nextHundredth(min: range.start, max: range.end)
            .toStringAsFixed(2);
      }
      _results = const [];
      _localError = null;
    });
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final inputs = <_IndexedTrialTarget>[];
    for (var index = 0; index < _visibleFieldCount; index++) {
      final absorption = parseCalculatorNumber(
        _absorptionControllers[index].text,
      );
      final thickness = _type == MeasurementType.flexure
          ? parseCalculatorNumber(_thicknessControllers[index].text)
          : null;
      if (index >= _baseElementCount && absorption == null) continue;
      inputs.add(
        _IndexedTrialTarget(
          fieldIndex: index,
          target: LaboratoryTrialTarget(
            absorption: absorption!,
            thicknessMm: thickness,
          ),
        ),
      );
    }

    setState(() {
      _calculating = true;
      _localError = null;
      _results = const [];
    });
    try {
      final predictions = await widget.controller.calculateLaboratoryTrials(
        type: _type,
        modelCode: _modelCode!,
        targets: inputs.map((entry) => entry.target).toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _results = List.generate(
          predictions.length,
          (index) => _DisplayedTrialResult(
            fieldIndex: inputs[index].fieldIndex,
            prediction: predictions[index],
          ),
          growable: false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _localError = friendlyCalculatorError(error));
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  String? _validateAbsorption(int index, String? value) {
    final text = value?.trim() ?? '';
    final optional = index >= _baseElementCount;
    final matchingThickness = _thicknessControllers[index].text.trim();
    if (text.isEmpty) {
      if (optional &&
          (_type == MeasurementType.compression || matchingThickness.isEmpty)) {
        return null;
      }
      return optional
          ? 'Complete la absorción de esta contra-muestra.'
          : 'Ingrese la absorción.';
    }
    final number = parseCalculatorNumber(text);
    if (number == null || number < 0 || number > 30) {
      return 'Use un valor entre 0 y 30.';
    }
    return null;
  }

  String? _validateThickness(int index, String? value) {
    if (_type != MeasurementType.flexure) return null;
    final text = value?.trim() ?? '';
    final optional = index >= _baseElementCount;
    final matchingAbsorption = _absorptionControllers[index].text.trim();
    if (text.isEmpty) {
      if (optional && matchingAbsorption.isEmpty) return null;
      return optional
          ? 'Complete el espesor de esta contra-muestra.'
          : 'Ingrese el espesor.';
    }
    final number = parseCalculatorNumber(text);
    if (number == null || number < 10 || number > 300) {
      return 'Use un valor entre 10 y 300 mm.';
    }
    return null;
  }

  int get _visibleFieldCount =>
      _testCounterSamples ? _totalFieldCount : _baseElementCount;

  void _clearResultsAfterEdit(String _) {
    if (_results.isEmpty && _localError == null) return;
    setState(() {
      _results = const [];
      _localError = null;
    });
  }

  void _clearAllFields() {
    for (final controller in _absorptionControllers) {
      controller.clear();
    }
    for (final controller in _thicknessControllers) {
      controller.clear();
    }
  }
}

class _SpecimenFields extends StatelessWidget {
  const _SpecimenFields({
    super.key,
    required this.label,
    required this.absorptionController,
    required this.thicknessController,
    required this.showThickness,
    required this.absorptionValidator,
    required this.thicknessValidator,
    required this.onChanged,
    this.optional = false,
  });

  final String label;
  final bool optional;
  final TextEditingController absorptionController;
  final TextEditingController thicknessController;
  final bool showThickness;
  final FormFieldValidator<String> absorptionValidator;
  final FormFieldValidator<String> thicknessValidator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (optional)
                Text(
                  'Opcional',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final absorptionField = TextFormField(
                key: ValueKey('$label-absorption'),
                controller: absorptionController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Absorción',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                validator: absorptionValidator,
                onChanged: onChanged,
              );
              final thicknessField = TextFormField(
                key: ValueKey('$label-thickness'),
                controller: thicknessController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Espesor',
                  suffixText: 'mm',
                  prefixIcon: Icon(Icons.height),
                ),
                validator: thicknessValidator,
                onChanged: onChanged,
              );
              if (!showThickness) return absorptionField;
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    absorptionField,
                    const SizedBox(height: 10),
                    thicknessField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: absorptionField),
                  const SizedBox(width: 12),
                  Expanded(child: thicknessField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RangeSetting extends StatelessWidget {
  const _RangeSetting({
    super.key,
    required this.title,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final String unit;
  final double minimum;
  final double maximum;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final fixed = maximum <= minimum;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                fixed
                    ? '${minimum.toStringAsFixed(2)} $unit'
                    : '${values.start.toStringAsFixed(2)}–${values.end.toStringAsFixed(2)} $unit',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (fixed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('El histórico solo contiene este valor.'),
            )
          else
            RangeSlider(
              min: minimum,
              max: maximum,
              values: values,
              labels: RangeLabels(
                values.start.toStringAsFixed(2),
                values.end.toStringAsFixed(2),
              ),
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _TrialResultsPanel extends StatelessWidget {
  const _TrialResultsPanel({required this.type, required this.results});

  final MeasurementType type;
  final List<_DisplayedTrialResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resultados del ensayo',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < results.length; index++) ...[
          _TrialResultCard(type: type, result: results[index]),
          if (index < results.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TrialResultCard extends StatelessWidget {
  const _TrialResultCard({required this.type, required this.result});

  final MeasurementType type;
  final _DisplayedTrialResult result;

  @override
  Widget build(BuildContext context) {
    final prediction = result.prediction;
    final scenario = prediction.typicalScenario;
    final unit = type.massUnit;
    final isCounterSample = result.fieldIndex >= _baseElementCount;
    final title = isCounterSample
        ? 'Elemento ${result.fieldIndex + 1} · Contra-muestra ${result.fieldIndex - _baseElementCount + 1}'
        : 'Elemento ${result.fieldIndex + 1}';

    return Card(
      key: ValueKey('trial-result-${result.fieldIndex + 1}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            MassLine(
              label: 'Masa saturada',
              value: formatMass(scenario.saturatedMass, type),
              unit: unit,
            ),
            if (type == MeasurementType.flexure)
              MassLine(
                label: 'Masa seca',
                value: formatMass(scenario.dryMass, type),
                unit: unit,
              ),
            MassLine(
              label: 'Masa inmersa',
              value: formatMass(scenario.immersedMass, type),
              unit: unit,
            ),
            if (type == MeasurementType.compression)
              MassLine(
                label: 'Masa seca',
                value: formatMass(scenario.dryMass, type),
                unit: unit,
              ),
            if (type == MeasurementType.compression &&
                scenario.naturalMass != null)
              MassLine(
                label: 'Masa natural',
                value: formatMass(scenario.naturalMass!, type),
                unit: unit,
              ),
            MassLine(
              label: 'Densidad',
              value: scenario.density.toStringAsFixed(0),
              unit: 'kg/m³',
            ),
            MassLine(
              label: 'Absorción',
              value: prediction.targetAbsorption.toStringAsFixed(2),
              unit: '%',
            ),
            if (prediction.warnings.isNotEmpty) ...[
              const Divider(height: 22),
              for (final warning in prediction.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndexedTrialTarget {
  const _IndexedTrialTarget({required this.fieldIndex, required this.target});

  final int fieldIndex;
  final LaboratoryTrialTarget target;
}

class _DisplayedTrialResult {
  const _DisplayedTrialResult({
    required this.fieldIndex,
    required this.prediction,
  });

  final int fieldIndex;
  final PredictionResult prediction;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

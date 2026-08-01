import 'package:flutter/material.dart';

import '../../services/app_controller.dart';
import 'laboratory_trials_calculator.dart';
import 'precision_calculator.dart';

enum _CalculatorMode { precision, trials }

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  _CalculatorMode _mode = _CalculatorMode.precision;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_CalculatorMode>(
                    key: const ValueKey('calculator-mode-selector'),
                    segments: const [
                      ButtonSegment(
                        value: _CalculatorMode.precision,
                        icon: Icon(Icons.tune_rounded),
                        label: Text('Precisión'),
                      ),
                      ButtonSegment(
                        value: _CalculatorMode.trials,
                        icon: Icon(Icons.science_outlined),
                        label: Text('Ensayos'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) {
                      setState(() => _mode = selection.first);
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode.index,
              children: [
                PrecisionCalculator(controller: widget.controller),
                LaboratoryTrialsCalculator(controller: widget.controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

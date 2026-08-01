import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/core/laboratory_randomizer.dart';
import 'package:masalab_historico/core/models.dart';
import 'package:masalab_historico/services/app_controller.dart';
import 'package:masalab_historico/ui/screens/calculator_screen.dart';
import 'package:masalab_historico/ui/screens/laboratory_trials_calculator.dart';

void main() {
  testWidgets('permite alternar entre Precisión y Ensayos', (tester) async {
    _usePhoneSize(tester);
    final controller = _controllerWithModels();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalculatorScreen(controller: controller)),
      ),
    );

    expect(find.text('Estimación de masas'), findsOneWidget);
    expect(find.text('Apoyo para ensayos de laboratorio'), findsNothing);

    await tester.tap(find.text('Ensayos'));
    await tester.pumpAndSettle();

    expect(find.text('Estimación de masas'), findsNothing);
    expect(find.text('Apoyo para ensayos de laboratorio'), findsOneWidget);
  });

  testWidgets('flexotracción muestra cinco filas y tres contra-muestras', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final controller = _controllerWithModels();
    addTearDown(controller.dispose);
    await _pumpTrials(tester, controller);

    expect(_absorptionFields(), findsNWidgets(5));
    expect(_thicknessFields(), findsNWidgets(5));

    final checkbox = find.byKey(const ValueKey('counter-samples-checkbox'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(_absorptionFields(), findsNWidgets(8));
    expect(_thicknessFields(), findsNWidgets(8));
    for (var index = 1; index <= 3; index++) {
      expect(find.byKey(ValueKey('trial-counter-$index')), findsOneWidget);
    }
  });

  testWidgets('compresión solicita únicamente absorciones', (tester) async {
    _usePhoneSize(tester);
    final controller = _controllerWithModels();
    addTearDown(controller.dispose);
    await _pumpTrials(tester, controller);

    await tester.tap(find.text('Compresión'));
    await tester.pumpAndSettle();

    expect(_absorptionFields(), findsNWidgets(5));
    expect(_thicknessFields(), findsNothing);
    expect(
      find.byKey(const ValueKey('random-absorptions-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('random-thicknesses-button')),
      findsNothing,
    );
  });

  testWidgets('los botones aleatorios llenan valores a centésimas en rango', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final controller = _controllerWithModels();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LaboratoryTrialsCalculator(
            controller: controller,
            randomizer: LaboratoryRandomizer.seeded(42),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AR8  ·  20 datos').last);
    await tester.pumpAndSettle();

    final absorptionButton = find.byKey(
      const ValueKey('random-absorptions-button'),
    );
    await tester.ensureVisible(absorptionButton);
    await tester.tap(absorptionButton);
    await tester.pump();

    final thicknessButton = find.byKey(
      const ValueKey('random-thicknesses-button'),
    );
    await tester.ensureVisible(thicknessButton);
    await tester.tap(thicknessButton);
    await tester.pump();

    for (final field in tester.widgetList<TextFormField>(_absorptionFields())) {
      final text = field.controller!.text;
      expect(text, matches(RegExp(r'^\d+\.\d{2}$')));
      expect(double.parse(text), inInclusiveRange(5.25, 6.75));
    }
    for (final field in tester.widgetList<TextFormField>(_thicknessFields())) {
      final text = field.controller!.text;
      expect(text, matches(RegExp(r'^\d+\.\d{2}$')));
      expect(double.parse(text), inInclusiveRange(78, 85));
    }
  });
}

Future<void> _pumpTrials(WidgetTester tester, AppController controller) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LaboratoryTrialsCalculator(controller: controller)),
    ),
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Finder _absorptionFields() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField &&
        widget.key is ValueKey<String> &&
        ((widget.key! as ValueKey<String>).value).endsWith('-absorption'),
  );
}

Finder _thicknessFields() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField &&
        widget.key is ValueKey<String> &&
        ((widget.key! as ValueKey<String>).value).endsWith('-thickness'),
  );
}

AppController _controllerWithModels() {
  final controller = AppController();
  controller.flexureModels = const [
    ModelSummary(
      type: MeasurementType.flexure,
      modelCode: 'AR8',
      totalSamples: 20,
      validSamples: 20,
      minAbsorption: 5.25,
      maxAbsorption: 6.75,
      minThicknessMm: 78,
      maxThicknessMm: 85,
    ),
  ];
  controller.compressionModels = const [
    ModelSummary(
      type: MeasurementType.compression,
      modelCode: 'M12L-DIV',
      totalSamples: 20,
      validSamples: 20,
      minAbsorption: 4.5,
      maxAbsorption: 7.5,
    ),
  ];
  return controller;
}

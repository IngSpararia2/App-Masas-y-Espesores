import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masalab_historico/ui/screens/splash_screen.dart';

void main() {
  testWidgets(
    'muestra el crédito al segundo y abre la app a los dos segundos',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(nextScreen: Text('Contenido principal')),
        ),
      );

      AnimatedOpacity creditOpacity() => tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('Developed by Ing. Samuel Parariá'),
          matching: find.byType(AnimatedOpacity),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(creditOpacity().opacity, 0);
      expect(find.text('Contenido principal'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(creditOpacity().opacity, 1);
      expect(find.text('Contenido principal'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Contenido principal'), findsOneWidget);
    },
  );
}

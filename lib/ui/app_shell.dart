import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import 'screens/calculator_screen.dart';
import 'screens/data_screen.dart';
import 'screens/import_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.initializing) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 18),
                  Text('Preparando la base de datos…'),
                ],
              ),
            ),
          );
        }

        final compactHeader = MediaQuery.sizeOf(context).width < 520;
        final pages = <Widget>[
          CalculatorScreen(controller: widget.controller),
          ImportScreen(controller: widget.controller),
          DataScreen(controller: widget.controller),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                const Icon(Icons.science_outlined),
                const SizedBox(width: 10),
                Text(compactHeader ? 'MasaLab' : 'MasaLab Histórico'),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.storage_outlined, size: 18),
                  label: Text(
                    compactHeader
                        ? widget.controller.stats.validMeasurements.toString()
                        : '${widget.controller.stats.validMeasurements} datos válidos',
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (widget.controller.errorMessage != null)
                _MessageBanner(
                  icon: Icons.error_outline,
                  message: widget.controller.errorMessage!,
                  background: Theme.of(context).colorScheme.errorContainer,
                  foreground: Theme.of(context).colorScheme.onErrorContainer,
                ),
              if (widget.controller.informationMessage != null)
                _MessageBanner(
                  icon: Icons.check_circle_outline,
                  message: widget.controller.informationMessage!,
                  background: const Color(0xFFE7F6EC),
                  foreground: const Color(0xFF166534),
                ),
              Expanded(
                child: IndexedStack(index: _index, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DeveloperCredit(),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(
                  () => _index = value,
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.calculate_outlined),
                    selectedIcon: Icon(Icons.calculate),
                    label: 'Calcular',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.upload_file_outlined),
                    selectedIcon: Icon(Icons.upload_file),
                    label: 'Importar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.dataset_outlined),
                    selectedIcon: Icon(Icons.dataset),
                    label: 'Datos',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit();

  static const _text =
      'App desarrollada por Ing. Samuel Parariá - Derechos Reservados';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: _text,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          _text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: foreground))),
        ],
      ),
    );
  }
}

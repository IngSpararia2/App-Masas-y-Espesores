import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../services/app_controller.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Importar históricos',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Puede seleccionar el resumen de compresión, el de flexotracción o ambos al mismo tiempo.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.rule_folder_outlined, size: 30),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Importación incremental',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Los registros existentes no se duplican. Si un ensayo cambió, se actualiza; si es nuevo, se agrega.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: controller.importing
                              ? null
                              : controller.pickAndImportFiles,
                          icon: controller.importing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_open_outlined),
                          label: Text(
                            controller.importing
                                ? 'Analizando e importando…'
                                : 'Seleccionar archivos XLSX',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Formato esperado: hoja “Resumen” generada por los scripts de compresión o flexotracción.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.lastImportResults.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Resultado de la importación',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final result in controller.lastImportResults) ...[
                    _ImportResultCard(result: result),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Controles automáticos',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _ControlLine(
                          icon: Icons.fingerprint,
                          text:
                              'Clave estable por ensayo y espécimen para evitar duplicados.',
                        ),
                        const _ControlLine(
                          icon: Icons.balance_outlined,
                          text:
                              'Recalcula absorción y densidad a partir de las masas.',
                        ),
                        const _ControlLine(
                          icon: Icons.filter_alt_outlined,
                          text:
                              'Marca como no utilizables los registros físicamente incoherentes.',
                        ),
                        const _ControlLine(
                          icon: Icons.merge_type,
                          text:
                              'Unifica variantes como “M12L DIV”, “M12L-DIV” y “M12L-DIP”.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportResultCard extends StatelessWidget {
  const _ImportResultCard({required this.result});

  final ImportSummary result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  result.alreadyImported
                      ? Icons.check_circle_outline
                      : Icons.table_view_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result.detectedType != null)
                  Chip(label: Text(result.detectedType!.label)),
              ],
            ),
            const SizedBox(height: 12),
            if (result.alreadyImported)
              const Text('Este mismo contenido ya estaba registrado.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CountChip(label: 'Nuevos', value: result.inserted),
                  _CountChip(label: 'Actualizados', value: result.updated),
                  _CountChip(label: 'Sin cambios', value: result.unchanged),
                  _CountChip(label: 'Rechazados', value: result.rejected),
                  _CountChip(
                    label: 'Válidos',
                    value: result.validForPrediction,
                  ),
                ],
              ),
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final note in result.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $note'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ControlLine extends StatelessWidget {
  const _ControlLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

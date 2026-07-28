import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../services/app_controller.dart';

class DataScreen extends StatelessWidget {
  const DataScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Base de datos local',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Los datos permanecen en el dispositivo y funcionan sin conexión.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatCard(
                          width: width,
                          icon: Icons.dataset_outlined,
                          label: 'Registros',
                          value: controller.stats.totalMeasurements.toString(),
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.verified_outlined,
                          label: 'Válidos',
                          value: controller.stats.validMeasurements.toString(),
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.view_in_ar_outlined,
                          label: 'Modelos compresión',
                          value: controller.stats.compressionModels.toString(),
                        ),
                        _StatCard(
                          width: width,
                          icon: Icons.horizontal_rule,
                          label: 'Modelos flexión',
                          value: controller.stats.flexureModels.toString(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Mantenimiento',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'Ubicación: ${controller.databasePath}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: controller.backingUp
                                  ? null
                                  : controller.createBackup,
                              icon: controller.backingUp
                                  ? const SizedBox.square(
                                      dimension: 17,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.backup_outlined),
                              label: const Text('Crear respaldo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.stats.totalMeasurements == 0
                                  ? null
                                  : () => _confirmReset(context),
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Reiniciar base'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Importaciones recientes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (controller.recentImports.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Todavía no se han importado archivos.'),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < controller.recentImports.length; i++) ...[
                          _ImportRow(batch: controller.recentImports[i]),
                          if (i < controller.recentImports.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar la base de datos?'),
        content: const Text(
          'Se eliminarán todos los históricos importados. Cree un respaldo antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearDatabase();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({required this.batch});

  final ImportBatch batch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          CircleAvatar(
            child: Icon(
              batch.type == MeasurementType.compression
                  ? Icons.view_in_ar_outlined
                  : Icons.horizontal_rule,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_date(batch.importedAt)} · +${batch.inserted} · '
                  '${batch.updated} actualizados · ${batch.rejected} rechazados',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Chip(label: Text(batch.type.label)),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}

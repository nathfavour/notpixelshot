import 'package:flutter/material.dart';
import '../services/index_service.dart';

class ProcessingStatus extends StatelessWidget {
  const ProcessingStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IndexProgress>(
      valueListenable: IndexService.progressNotifier,
      builder: (context, progress, child) {
        if (progress.total == 0) return const SizedBox.shrink();

        final percentage =
            (progress.processed / progress.total * 100).toStringAsFixed(1);

        return Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Processing Screenshots',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.processed / progress.total,
                    minHeight: 8,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progress.processed} of ${progress.total} screenshots processed',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${progress.total - progress.processed} remaining',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
                if (progress.current.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${progress.current.split('/').last}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trim_job.dart';
import '../providers/app_state_provider.dart';

/// Widget for displaying trim jobs
class TrimJobsWidget extends StatelessWidget {
  const TrimJobsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trim Jobs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      if (appState.trimJobs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            appState.clearCompletedJobs();
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Clear Completed'),
                        ),
                      if (appState.trimJobs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            appState.clearAllJobs();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear All'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: appState.trimJobs.isNotEmpty
                  ? ListView.builder(
                      itemCount: appState.trimJobs.length,
                      itemBuilder: (context, index) {
                        final job = appState.trimJobs[index];
                        final duration = Duration(
                          milliseconds:
                              ((job.endTime - job.startTime) * 1000).toInt(),
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: ListTile(
                            title: Text(
                              job.outputFileName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration: ${_formatDuration(duration)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (job.error != null)
                                  Text(
                                    'Error: ${job.error}',
                                    style: const TextStyle(color: Colors.red),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                // Progress indicator with animation
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: LinearProgressIndicator(
                                    value: job.progress >= 0 
                                        ? job.progress > 0.99 ? 1.0 : job.progress // Ensure 100% is shown when complete
                                        : 0,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      job.progress < 0
                                          ? Colors.red
                                          : job.progress > 0.95
                                              ? Colors.lightGreen
                                              : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Status text with animation
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: job.progress == 1.0 || job.progress < 0 ? FontWeight.bold : FontWeight.normal,
                                    color: job.progress == 1.0
                                        ? Colors.green
                                        : job.progress < 0
                                            ? Colors.red
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  child: Text(_getJobStatusText(job)),
                                ),
                              ],
                            ),
                            trailing: _buildJobStatusIcon(job),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        'No trim jobs',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Format a duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get status text for a job
  String _getJobStatusText(TrimJob job) {
    if (job.error != null) {
      return 'Failed';
    }
    if (job.progress < 0) {
      return 'Error';
    }
    if (job.progress >= 0.99) {
      return 'Completed';
    }
    if (job.progress > 0) {
      return 'Processing (${(job.progress * 100).toInt()}%)';
    }
    return 'Pending';
  }

  /// Build status icon for a job
  Widget _buildJobStatusIcon(TrimJob job) {
    if (job.error != null || job.progress < 0) {
      return const Icon(Icons.error_outline, color: Colors.red);
    }
    if (job.progress >= 0.99) {
      return const Icon(Icons.check_circle_outline, color: Colors.green);
    }
    if (job.progress > 0) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Icon(Icons.hourglass_empty, color: Colors.grey);
  }
}

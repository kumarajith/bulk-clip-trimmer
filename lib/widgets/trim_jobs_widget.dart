import 'package:flutter/material.dart';

import '../models/trim_job.dart';
import '../providers/app_state_provider.dart';

/// Widget for displaying trim jobs
class TrimJobsWidget extends StatelessWidget {
  /// App state provider
  final AppStateProvider appState;

  /// Constructor
  const TrimJobsWidget({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final showJobsPanel = appState.showJobsPanel;
        final trimJobs = appState.trimJobs;
        
        return Column(
          mainAxisSize: MainAxisSize.min, // Set to min to avoid unbounded height issues
          children: [
            // Panel header
            InkWell(
              onTap: appState.toggleJobsPanel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(showJobsPanel ? Icons.arrow_drop_down : Icons.arrow_drop_up),
                    const SizedBox(width: 8),
                    const Text(
                      'Trim Jobs',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (trimJobs.isNotEmpty)
                      Chip(
                        label: Text(trimJobs.length.toString()),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Jobs list with AnimatedContainer for smooth transitions
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: showJobsPanel ? 200.0 : 0.0, // Fixed height that animates between 0 and 200
              child: showJobsPanel ? Container(
                child: trimJobs.isEmpty
                  ? Center(
                      child: Text(
                        'No trim jobs. Add a job using the form above.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true, // Important to avoid unbounded height issues
                      itemCount: trimJobs.length,
                      itemBuilder: (context, index) {
                        final job = trimJobs[index];
                        final fileName = job.filePath.split('/').last;
                        
                        return ListTile(
                          title: Text(
                            '${job.outputFileName} (${job.audioOnly ? 'Audio Only' : 'Video'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Source: $fileName',
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('Trim: ${_formatDuration(job.startDuration)} - ${_formatDuration(job.endDuration)}'),
                              if (job.error != null)
                                Text(
                                  'Error: ${job.error}',
                                  style: const TextStyle(color: Colors.red),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              LinearProgressIndicator(
                                value: job.progress >= 0 ? job.progress : 0,
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  job.progress == 1.0
                                      ? Colors.green
                                      : job.progress < 0
                                          ? Colors.red
                                          : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          trailing: _buildJobStatusIcon(job),
                        );
                      },
                    ),
              ) : null,
            ),
          ],
        );
      },
    );
  }

  /// Build an icon representing the job status
  Widget _buildJobStatusIcon(TrimJob job) {
    if (job.progress == 1.0) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (job.error != null || job.progress < 0) {
      return const Icon(Icons.error, color: Colors.red);
    } else if (job.progress > 0) {
      return const Icon(Icons.hourglass_bottom, color: Colors.orange);
    } else {
      return const Icon(Icons.pending, color: Colors.grey);
    }
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../providers/app_state_provider.dart';
import '../models/trim_job.dart';

/// Widget for displaying trim jobs
class TrimJobsWidget extends StatelessWidget {
  /// App state provider
  final AppStateProvider appStateProvider;

  /// Constructor
  const TrimJobsWidget({
    Key? key,
    required this.appStateProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStateProvider,
      builder: (context, child) {
        final trimJobs = appStateProvider.trimJobs;
        
        if (trimJobs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Card(
          margin: const EdgeInsets.all(8.0),
          color: Theme.of(context).cardColor,
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.content_cut, 
                      color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8.0),
                    Text(
                      'Trim Jobs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const Divider(height: 1),
                const SizedBox(height: 8.0),
                for (final job in trimJobs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildJobItem(context, job),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildJobItem(BuildContext context, TrimJob job) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  color: job.error != null
                      ? theme.colorScheme.error
                      : job.progress >= 1.0
                          ? Colors.green
                          : theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    job.error != null
                        ? Icons.error
                        : job.progress >= 1.0
                            ? Icons.check
                            : Icons.hourglass_bottom,
                    color: Colors.white,
                    size: 16.0,
                  ),
                ),
              ),
              SizedBox(width: 12.0),
              // Filename
              Expanded(
                child: Text(
                  path.basename(job.filePath),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.0),
          // Progress indicator and text
          if (job.progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  // Progress percentage text
                  Container(
                    width: 45,
                    child: Text(
                      // Format to one decimal place for consistency
                      '${(job.progress * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Progress bar
                  Expanded(
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          Container(
                            height: 6.0,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                          ),
                          // Use FractionallySizedBox for reliable progress display
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3.0),
                            child: FractionallySizedBox(
                              key: ValueKey('progress-${job.filePath.hashCode}'),
                              widthFactor: job.progress.clamp(0.0, 1.0),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 6.0,
                                color: job.error != null ? theme.colorScheme.error : 
                                       job.progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (job.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                job.error!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }
}

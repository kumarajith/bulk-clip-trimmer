import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';

/// Widget for the trim job form
class TrimFormWidget extends StatelessWidget {
  /// Constructor
  const TrimFormWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final hasVideo = appState.currentVideo != null;
        final hasTrimRange = appState.trimRange != null;
        final hasLabels = appState.labelFolders.any((lf) => lf.isSelected);
        
        // Check if form is valid
        final isFormValid = hasVideo && 
                           hasTrimRange && 
                           hasLabels && 
                           appState.outputFileName.isNotEmpty;
        
        // Use LayoutBuilder to make the widget responsive
        return LayoutBuilder(
          builder: (context, constraints) {
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form title
                        Text(
                          'Trim Settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        
                        // Output file name
                        TextField(
                          controller: TextEditingController(text: appState.outputFileName),
                          decoration: InputDecoration(
                            labelText: 'Output File Name',
                            hintText: 'Enter output file name',
                            border: const OutlineInputBorder(),
                            errorText: appState.outputFileName.isEmpty && hasVideo
                                ? 'Please enter a file name'
                                : null,
                          ),
                          onChanged: (value) => appState.setOutputFileName(value),
                        ),
                        const SizedBox(height: 16),
                        
                        // Add to queue button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add to Queue'),
                            onPressed: isFormValid ? appState.addTrimJob : null,
                          ),
                        ),
                        
                        // Form validation messages
                        if (!hasVideo || !hasTrimRange || !hasLabels)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!hasVideo)
                                  const Text(
                                    '• Select a video from the playlist',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                if (!hasTrimRange)
                                  const Text(
                                    '• Set trim range using the seekbar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                if (!hasLabels)
                                  const Text(
                                    '• Select at least one output folder',
                                    style: TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

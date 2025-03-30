import 'package:flutter/material.dart';

import '../providers/app_state_provider.dart';

/// Widget for the trim job form
class TrimFormWidget extends StatefulWidget {
  /// App state provider
  final AppStateProvider appState;

  /// Constructor
  const TrimFormWidget({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _TrimFormWidgetState createState() => _TrimFormWidgetState();
}

class _TrimFormWidgetState extends State<TrimFormWidget> {
  /// Controller for the output file name field
  final _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fileNameController.addListener(_updateOutputFileName);
  }

  @override
  void dispose() {
    _fileNameController.removeListener(_updateOutputFileName);
    _fileNameController.dispose();
    super.dispose();
  }

  /// Update the output file name in the app state
  void _updateOutputFileName() {
    widget.appState.setOutputFileName(_fileNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final hasVideo = widget.appState.currentVideo != null;
        final hasTrimRange = widget.appState.trimRange != null;
        final hasLabels = widget.appState.labelFolders.any((lf) => lf.isSelected);
        
        // Check if form is valid
        final isFormValid = hasVideo && 
                           hasTrimRange && 
                           hasLabels && 
                           _fileNameController.text.isNotEmpty;
        
        return Card(
          margin: const EdgeInsets.all(8.0),
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
                  controller: _fileNameController,
                  decoration: InputDecoration(
                    labelText: 'Output File Name',
                    hintText: 'Enter output file name',
                    border: const OutlineInputBorder(),
                    errorText: _fileNameController.text.isEmpty && hasVideo
                        ? 'Please enter a file name'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Add to queue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Queue'),
                    onPressed: isFormValid ? widget.appState.addTrimJob : null,
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
        );
      },
    );
  }
}

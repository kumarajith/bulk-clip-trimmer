import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/label_folder.dart';
import '../providers/app_state_provider.dart';
import '../services/label_folder_service.dart';

/// Widget for managing label folders
class LabelFoldersWidget extends StatelessWidget {
  /// Constructor
  const LabelFoldersWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get appState from provider
    final appState = Provider.of<AppStateProvider>(context);
    
    // Use Consumer to rebuild when labelFolders changes
    return Consumer<AppStateProvider>( 
      builder: (context, appStateConsumer, _) {
        final labelFolders = appStateConsumer.labelFolders;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with settings button - keep this fixed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text(
                    'Output Folders:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Configure label folders',
                    onPressed: () => _showLabelFoldersDialog(context, appState),
                  ),
                ],
              ),
            ),
            
            // Make the content area scrollable
            Expanded(
              child: SingleChildScrollView(
                child: labelFolders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No output folders configured. Click the settings icon to add folders.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: labelFolders.map((labelFolder) {
                              return FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(labelFolder.label),
                                    if (labelFolder.audioOnly)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4.0),
                                        child: Icon(
                                          Icons.music_note,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                                selected: labelFolder.isSelected,
                                onSelected: (selected) {
                                  appState.toggleLabelSelection(labelFolder.label);
                                },
                                tooltip: '${labelFolder.folderPath}${labelFolder.audioOnly ? ' (Audio Only)' : ''}',
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          // Display details of selected folders with audio toggle
                          ...labelFolders.where((lf) => lf.isSelected).map((folder) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    folder.audioOnly ? Icons.music_note : Icons.videocam,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      folder.label,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: Icon(
                                      folder.audioOnly ? Icons.music_note : Icons.videocam,
                                      size: 16,
                                    ),
                                    label: Text(folder.audioOnly ? 'Audio Only' : 'Video + Audio'),
                                    onPressed: () {
                                      appState.toggleAudioOnly(folder.label);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show the label folders configuration dialog
  Future<void> _showLabelFoldersDialog(BuildContext context, AppStateProvider appState) async {
    // Create a local copy of label folders for editing
    final labelFolders = List<LabelFolder>.from(appState.labelFolders);
    
    // Add an empty row if needed
    if (labelFolders.isEmpty || 
        (labelFolders.last.label.isNotEmpty && labelFolders.last.folderPath.isNotEmpty)) {
      labelFolders.add(LabelFolder(label: '', folderPath: ''));
    }
    
    // Create a separate StatefulWidget for the dialog content to properly manage controllers
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _LabelFolderDialog(
          initialFolders: labelFolders,
          onSave: (updatedFolders) {
            // Process the updated folders
            final validFolders = updatedFolders
                .where((lf) => lf.label.isNotEmpty && lf.folderPath.isNotEmpty)
                .toList();
            
            // Get existing labels
            final existingLabels = appState.labelFolders
                .map((lf) => lf.label)
                .toSet();
            
            // Get new labels
            final newLabels = validFolders
                .map((lf) => lf.label)
                .toSet();
            
            // Remove folders that no longer exist
            for (final label in existingLabels) {
              if (!newLabels.contains(label)) {
                appState.removeLabelFolder(label);
              }
            }
            
            // Add or update label folders
            for (final labelFolder in validFolders) {
              appState.addLabelFolder(labelFolder);
            }
          },
        );
      },
    );
  }
}

/// Dialog for editing label folders
class _LabelFolderDialog extends StatefulWidget {
  /// Initial folders
  final List<LabelFolder> initialFolders;
  
  /// Callback when folders are saved
  final Function(List<LabelFolder>) onSave;

  /// Constructor
  const _LabelFolderDialog({
    Key? key,
    required this.initialFolders,
    required this.onSave,
  }) : super(key: key);

  @override
  _LabelFolderDialogState createState() => _LabelFolderDialogState();
}

class _LabelFolderDialogState extends State<_LabelFolderDialog> {
  /// Label folders
  late List<LabelFolder> _labelFolders;
  
  /// Text editing controllers
  late List<TextEditingController> _controllers;
  
  /// Label folder service
  final _labelFolderService = LabelFolderService();

  @override
  void initState() {
    super.initState();
    
    // Initialize label folders
    _labelFolders = List<LabelFolder>.from(widget.initialFolders);
    
    // Initialize controllers
    _controllers = List.generate(
      _labelFolders.length,
      (index) => TextEditingController(text: _labelFolders[index].label),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Add a new row
  void _addRow() {
    setState(() {
      _labelFolders.add(LabelFolder(label: '', folderPath: ''));
      _controllers.add(TextEditingController());
    });
  }

  /// Remove a row
  void _removeRow(int index) {
    setState(() {
      if (_labelFolders.length > 1) {
        // Remove the controller first
        final controller = _controllers.removeAt(index);
        controller.dispose();
        
        // Then remove the folder
        _labelFolders.removeAt(index);
      } else {
        // Just clear the first row
        _labelFolders[0] = LabelFolder(label: '', folderPath: '');
        _controllers[0].clear();
      }
    });
  }

  /// Update label
  void _updateLabel(int index, String value) {
    setState(() {
      _labelFolders[index] = _labelFolders[index].copyWith(label: value);
      
      // Add a new row if needed
      if (index == _labelFolders.length - 1 && 
          value.isNotEmpty && 
          _labelFolders[index].folderPath.isNotEmpty) {
        _addRow();
      }
    });
  }

  /// Update folder path
  void _updateFolderPath(int index, String path) {
    setState(() {
      _labelFolders[index] = _labelFolders[index].copyWith(folderPath: path);
      
      // Add a new row if needed
      if (index == _labelFolders.length - 1 && 
          _labelFolders[index].label.isNotEmpty && 
          path.isNotEmpty) {
        _addRow();
      }
    });
  }

  /// Toggle audio only
  void _toggleAudioOnly(int index, bool? value) {
    setState(() {
      _labelFolders[index] = _labelFolders[index].copyWith(
        audioOnly: value ?? false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Label Folders'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(color: Theme.of(context).dividerColor),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Label', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Folder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ...List.generate(_labelFolders.length, (index) {
                final labelFolder = _labelFolders[index];
                return TableRow(
                  children: [
                    SizedBox(
                      height: 60,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _controllers[index],
                          decoration: const InputDecoration(
                            hintText: 'Enter label',
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => _updateLabel(index, value),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result = await _labelFolderService.pickFolderForLabel();
                                  if (result != null) {
                                    _updateFolderPath(index, result);
                                  }
                                },
                                child: Text(
                                  labelFolder.folderPath.isNotEmpty 
                                      ? labelFolder.folderPath.split('/').last 
                                      : 'Select Folder',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (labelFolder.label.isNotEmpty || labelFolder.folderPath.isNotEmpty) 
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeRow(index),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Checkbox(
                            value: labelFolder.audioOnly,
                            onChanged: (value) => _toggleAudioOnly(index, value),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Save valid label folders
            widget.onSave(_labelFolders);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

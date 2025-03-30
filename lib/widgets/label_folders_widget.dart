import 'package:flutter/material.dart';

import '../models/label_folder.dart';
import '../providers/app_state_provider.dart';
import '../services/label_folder_service.dart';

/// Widget for managing label folders
class LabelFoldersWidget extends StatefulWidget {
  /// App state provider
  final AppStateProvider appState;

  /// Constructor
  const LabelFoldersWidget({
    Key? key,
    required this.appState,
  }) : super(key: key);

  @override
  _LabelFoldersWidgetState createState() => _LabelFoldersWidgetState();
}

class _LabelFoldersWidgetState extends State<LabelFoldersWidget> {
  /// Label folder service
  final _labelFolderService = LabelFolderService();
  
  /// Show the label folders configuration dialog
  Future<void> _showLabelFoldersDialog() async {
    final labelFolders = List<LabelFolder>.from(widget.appState.labelFolders);
    
    // Add an empty row if needed
    if (labelFolders.isEmpty || 
        (labelFolders.last.label.isNotEmpty && labelFolders.last.folderPath.isNotEmpty)) {
      labelFolders.add(LabelFolder(label: '', folderPath: ''));
    }
    
    final controllers = List.generate(
      labelFolders.length,
      (index) => TextEditingController(text: labelFolders[index].label),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Label Folders'),
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
                      ...labelFolders.asMap().entries.map((entry) {
                        final index = entry.key;
                        final labelFolder = entry.value;
                        
                        return TableRow(
                          children: [
                            SizedBox(
                              height: 60,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: controllers[index],
                                  decoration: const InputDecoration(
                                    hintText: 'Enter label',
                                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      labelFolders[index] = labelFolders[index].copyWith(label: value);
                                      
                                      // Add a new row if needed
                                      if (index == labelFolders.length - 1 && 
                                          value.isNotEmpty && 
                                          labelFolders[index].folderPath.isNotEmpty) {
                                        labelFolders.add(LabelFolder(label: '', folderPath: ''));
                                        controllers.add(TextEditingController());
                                      }
                                    });
                                  },
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
                                            setDialogState(() {
                                              labelFolders[index] = labelFolders[index].copyWith(folderPath: result);
                                              
                                              // Add a new row if needed
                                              if (index == labelFolders.length - 1 && 
                                                  labelFolders[index].label.isNotEmpty && 
                                                  result.isNotEmpty) {
                                                labelFolders.add(LabelFolder(label: '', folderPath: ''));
                                                controllers.add(TextEditingController());
                                              }
                                            });
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
                                        onPressed: () {
                                          setDialogState(() {
                                            if (labelFolders.length > 1) {
                                              labelFolders.removeAt(index);
                                              controllers.removeAt(index);
                                            } else {
                                              labelFolders[0] = LabelFolder(label: '', folderPath: '');
                                              controllers[0].clear();
                                            }
                                          });
                                        },
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
                                    onChanged: (value) {
                                      setDialogState(() {
                                        labelFolders[index] = labelFolders[index].copyWith(
                                          audioOnly: value ?? false,
                                        );
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
                    final validLabelFolders = labelFolders
                        .where((lf) => lf.label.isNotEmpty && lf.folderPath.isNotEmpty)
                        .toList();
                    
                    for (final labelFolder in validLabelFolders) {
                      _labelFolderService.addLabelFolder(labelFolder);
                    }
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose controllers
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final labelFolders = widget.appState.labelFolders;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    onPressed: _showLabelFoldersDialog,
                  ),
                ],
              ),
            ),
            if (labelFolders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No output folders configured. Click the settings icon to add folders.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              )
            else
              Padding(
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
                            widget.appState.toggleLabelSelection(labelFolder.label);
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
                            Text(
                              folder.label,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: Icon(
                                folder.audioOnly ? Icons.music_note : Icons.videocam,
                                size: 16,
                              ),
                              label: Text(folder.audioOnly ? 'Audio Only' : 'Video + Audio'),
                              onPressed: () {
                                widget.appState.toggleAudioOnly(folder.label);
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
          ],
        );
      },
    );
  }
}

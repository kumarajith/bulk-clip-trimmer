import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/label_folder.dart';

/// Service class for managing label folders
class LabelFolderService {
  /// Singleton instance
  static final LabelFolderService _instance = LabelFolderService._internal();

  /// Factory constructor
  factory LabelFolderService() => _instance;

  /// Internal constructor
  LabelFolderService._internal();

  /// Storage file name
  static const String _storageFileName = 'label_folders.json';

  /// List of label folders
  final List<LabelFolder> _labelFolders = [];
  
  /// Controller for label folder updates
  final _labelFoldersController = ValueNotifier<List<LabelFolder>>([]);
  
  /// Video service instance
  // final _videoService = VideoService();

  /// Get the list of label folders
  List<LabelFolder> get labelFolders => List.unmodifiable(_labelFolders);

  /// Get the label folders stream
  ValueNotifier<List<LabelFolder>> get labelFoldersNotifier => _labelFoldersController;

  /// Load label folders from storage
  Future<List<LabelFolder>> loadLabelFolders() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_storageFileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        
        _labelFolders.clear();
        _labelFolders.addAll(
          jsonList.map((json) => LabelFolder.fromMap(json as Map<String, dynamic>)).toList(),
        );
        
        _labelFoldersController.value = List.from(_labelFolders);
        return _labelFolders;
      }
    } catch (e) {
      debugPrint('Error loading label folders: $e');
    }
    
    return [];
  }

  /// Save label folders to storage
  Future<void> saveLabelFolders() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_storageFileName');

      final jsonList = _labelFolders.map((folder) => folder.toMap()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
      
      _labelFoldersController.value = List.from(_labelFolders);
    } catch (e) {
      debugPrint('Error saving label folders: $e');
    }
  }

  /// Add a new label folder
  void addLabelFolder(LabelFolder labelFolder) {
    // Check if label already exists
    final index = _labelFolders.indexWhere((lf) => lf.label == labelFolder.label);
    
    if (index != -1) {
      // Update existing label folder
      _labelFolders[index] = labelFolder;
    } else {
      // Add new label folder
      _labelFolders.add(labelFolder);
    }
    
    saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Remove a label folder
  void removeLabelFolder(String label) {
    _labelFolders.removeWhere((lf) => lf.label == label);
    saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Update a label folder
  void updateLabelFolder(LabelFolder labelFolder) {
    final index = _labelFolders.indexWhere((lf) => lf.label == labelFolder.label);
    
    if (index != -1) {
      _labelFolders[index] = labelFolder;
      saveLabelFolders();
      _labelFoldersController.value = List.from(_labelFolders);
    }
  }

  /// Toggle selection state of a label folder
  void toggleLabelFolderSelection(String label) {
    final index = _labelFolders.indexWhere((lf) => lf.label == label);
    
    if (index != -1) {
      _labelFolders[index] = _labelFolders[index].copyWith(
        isSelected: !_labelFolders[index].isSelected,
      );
      saveLabelFolders();
      _labelFoldersController.value = List.from(_labelFolders);
    }
  }

  /// Get selected label folders
  List<LabelFolder> getSelectedLabelFolders() {
    return _labelFolders.where((lf) => lf.isSelected).toList();
  }

  /// Get selected folder paths
  List<String> getSelectedFolderPaths() {
    return _labelFolders
        .where((lf) => lf.isSelected)
        .map((lf) => lf.folderPath)
        .toList();
  }

  /// Clear all selections
  void clearSelections() {
    for (var i = 0; i < _labelFolders.length; i++) {
      _labelFolders[i] = _labelFolders[i].copyWith(isSelected: false);
    }
    saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Pick a folder for a label
  Future<String?> pickFolderForLabel() async {
    final result = await FilePicker.platform.getDirectoryPath();
    return result;
  }

  /// Dispose resources
  void dispose() {
    _labelFoldersController.dispose();
  }
}

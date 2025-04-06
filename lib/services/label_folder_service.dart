import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../models/label_folder.dart';
import 'app_directory_service.dart';
import 'logging_service.dart';

/// Service class for managing label folders
class LabelFolderService {
  /// Singleton instance
  static final LabelFolderService _instance = LabelFolderService._internal();

  /// Factory constructor
  factory LabelFolderService() => _instance;

  /// App directory service
  final _appDirectoryService = AppDirectoryService();

  /// Logging service
  final _loggingService = LoggingService();

  /// Internal constructor
  LabelFolderService._internal();

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
      // Get the label folders file path from the app directory service
      final filePath = await _appDirectoryService.getLabelFoldersFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        
        // Check if the file is empty or contains invalid JSON
        if (jsonString.trim().isEmpty) {
          await _loggingService.warning('Label folders file exists but is empty');
          return [];
        }
        
        try {
          final jsonList = jsonDecode(jsonString) as List<dynamic>;
          
          _labelFolders.clear();
          _labelFolders.addAll(
            jsonList.map((json) => LabelFolder.fromMap(json as Map<String, dynamic>)).toList(),
          );
          
          _labelFoldersController.value = List.from(_labelFolders);
          await _loggingService.info('Loaded ${_labelFolders.length} label folders');
          await _loggingService.debug('Label folders file path', details: filePath);
          return _labelFolders;
        } catch (jsonError) {
          await _loggingService.error('Error parsing label folders JSON', details: jsonError.toString());
          // Create a backup of the corrupted file
          final backupPath = '$filePath.bak.${DateTime.now().millisecondsSinceEpoch}';
          await file.copy(backupPath);
          await _loggingService.info('Created backup of corrupted label folders file', details: backupPath);
          
          // Return empty list and create a new file later
          return [];
        }
      } else {
        await _loggingService.info('No label folders file found, starting with empty list');
        await _loggingService.debug('Expected label folders file path', details: filePath);
        
        // Create an empty file
        await file.create(recursive: true);
        await file.writeAsString('[]');
        await _loggingService.info('Created empty label folders file');
      }
    } catch (e) {
      await _loggingService.error('Error loading label folders', details: e.toString());
    }
    
    return [];
  }

  /// Save label folders to storage
  Future<void> saveLabelFolders() async {
    try {
      // Get the label folders file path from the app directory service
      final filePath = await _appDirectoryService.getLabelFoldersFilePath();
      final file = File(filePath);

      final jsonList = _labelFolders.map((folder) => folder.toMap()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
      
      _labelFoldersController.value = List.from(_labelFolders);
      await _loggingService.info('Saved ${_labelFolders.length} label folders');
    } catch (e) {
      await _loggingService.error('Error saving label folders', details: e.toString());
    }
  }

  /// Add a new label folder
  Future<void> addLabelFolder(LabelFolder labelFolder) async {
    // Check if label already exists
    final index = _labelFolders.indexWhere((lf) => lf.label == labelFolder.label);
    
    if (index != -1) {
      // Update existing label folder
      _labelFolders[index] = labelFolder;
      await _loggingService.info('Updated label folder: ${labelFolder.label}');
    } else {
      // Add new label folder
      _labelFolders.add(labelFolder);
      await _loggingService.info('Added new label folder: ${labelFolder.label}');
    }
    
    await saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Remove a label folder
  Future<void> removeLabelFolder(String label) async {
    _labelFolders.removeWhere((lf) => lf.label == label);
    await _loggingService.info('Removed label folder: $label');
    await saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Update a label folder
  Future<void> updateLabelFolder(LabelFolder labelFolder) async {
    final index = _labelFolders.indexWhere((lf) => lf.label == labelFolder.label);
    
    if (index != -1) {
      _labelFolders[index] = labelFolder;
      await _loggingService.info('Updated label folder: ${labelFolder.label}');
      await saveLabelFolders();
      _labelFoldersController.value = List.from(_labelFolders);
    }
  }

  /// Toggle selection state of a label folder
  Future<void> toggleLabelFolderSelection(String label) async {
    final index = _labelFolders.indexWhere((lf) => lf.label == label);
    
    if (index != -1) {
      final newState = !_labelFolders[index].isSelected;
      _labelFolders[index] = _labelFolders[index].copyWith(
        isSelected: newState,
      );
      await _loggingService.info('Toggled label folder selection: $label (${newState ? 'selected' : 'unselected'})');
      await saveLabelFolders();
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
  Future<void> clearSelections() async {
    for (var i = 0; i < _labelFolders.length; i++) {
      _labelFolders[i] = _labelFolders[i].copyWith(isSelected: false);
    }
    await _loggingService.info('Cleared all label folder selections');
    await saveLabelFolders();
    _labelFoldersController.value = List.from(_labelFolders);
  }

  /// Pick a folder for a label
  Future<String?> pickFolderForLabel() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await _loggingService.info('Selected folder: $result');
    }
    return result;
  }

  /// Dispose resources
  void dispose() {
    _labelFoldersController.dispose();
  }
}

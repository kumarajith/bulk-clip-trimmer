import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing application directories
class AppDirectoryService {
  /// Singleton instance
  static final AppDirectoryService _instance = AppDirectoryService._internal();

  /// Factory constructor
  factory AppDirectoryService() => _instance;

  /// Internal constructor
  AppDirectoryService._internal();

  /// Root directory for application data
  Directory? _appDataDirectory;

  /// Directory for label folders data
  Directory? _labelFoldersDirectory;

  /// Directory for logs
  Directory? _logsDirectory;

  /// Directory for extracted binaries
  Directory? _binDirectory;

  /// Initialize the application directories
  Future<void> initialize() async {
    try {
      // Get the documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      
      // Create the app data directory
      _appDataDirectory = Directory('${documentsDir.path}/BulkClipTrimmer');
      if (!await _appDataDirectory!.exists()) {
        await _appDataDirectory!.create(recursive: true);
      }
      
      // Create subdirectories
      _labelFoldersDirectory = Directory('${_appDataDirectory!.path}/LabelFolders');
      if (!await _labelFoldersDirectory!.exists()) {
        await _labelFoldersDirectory!.create(recursive: true);
      }
      
      _logsDirectory = Directory('${_appDataDirectory!.path}/Logs');
      if (!await _logsDirectory!.exists()) {
        await _logsDirectory!.create(recursive: true);
      }
      
      _binDirectory = Directory('${_appDataDirectory!.path}/bin');
      if (!await _binDirectory!.exists()) {
        await _binDirectory!.create(recursive: true);
      }
      
      debugPrint('App directories initialized at: ${_appDataDirectory!.path}');
    } catch (e) {
      debugPrint('Error initializing app directories: $e');
      rethrow;
    }
  }

  /// Get the application data directory
  Future<Directory> getAppDataDirectory() async {
    if (_appDataDirectory == null) {
      await initialize();
    }
    return _appDataDirectory!;
  }

  /// Get the label folders directory
  Future<Directory> getLabelFoldersDirectory() async {
    if (_labelFoldersDirectory == null) {
      await initialize();
    }
    return _labelFoldersDirectory!;
  }

  /// Get the logs directory
  Future<Directory> getLogsDirectory() async {
    if (_logsDirectory == null) {
      await initialize();
    }
    return _logsDirectory!;
  }

  /// Get the bin directory
  Future<Directory> getBinDirectory() async {
    if (_binDirectory == null) {
      await initialize();
    }
    return _binDirectory!;
  }

  /// Get path to the label folders file
  Future<String> getLabelFoldersFilePath() async {
    final dir = await getLabelFoldersDirectory();
    return '${dir.path}/label_folders.json';
  }

  /// Get path to the application log file
  Future<String> getLogFilePath() async {
    final dir = await getLogsDirectory();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${dir.path}/app_log_$dateStr.txt';
  }
}

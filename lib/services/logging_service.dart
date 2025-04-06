import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_directory_service.dart';

/// Log level enum
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical
}

/// Log entry class
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? details;

  LogEntry({
    required this.level,
    required this.message,
    this.details,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final levelStr = level.toString().split('.').last.toUpperCase();
    final timeStr = '${timestamp.toIso8601String()}';
    final detailsStr = details != null ? '\nDetails: $details' : '';
    return '[$timeStr] $levelStr: $message$detailsStr';
  }
}

/// Service for application logging
class LoggingService {
  /// Singleton instance
  static final LoggingService _instance = LoggingService._internal();

  /// Factory constructor
  factory LoggingService() => _instance;

  /// App directory service
  final _appDirectoryService = AppDirectoryService();

  /// Internal constructor
  LoggingService._internal();

  /// Minimum log level to record
  LogLevel _minLogLevel = LogLevel.info;

  /// Set the minimum log level
  set minLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  /// Log a message
  Future<void> log(LogLevel level, String message, {String? details}) async {
    // Skip if below minimum log level
    if (level.index < _minLogLevel.index) {
      return;
    }

    final entry = LogEntry(
      level: level,
      message: message,
      details: details,
    );

    // Print to console
    debugPrint(entry.toString());

    // Write to log file
    await _writeToLogFile(entry);
  }

  /// Log a debug message
  Future<void> debug(String message, {String? details}) async {
    await log(LogLevel.debug, message, details: details);
  }

  /// Log an info message
  Future<void> info(String message, {String? details}) async {
    await log(LogLevel.info, message, details: details);
  }

  /// Log a warning message
  Future<void> warning(String message, {String? details}) async {
    await log(LogLevel.warning, message, details: details);
  }

  /// Log an error message
  Future<void> error(String message, {String? details}) async {
    await log(LogLevel.error, message, details: details);
  }

  /// Log a critical message
  Future<void> critical(String message, {String? details}) async {
    await log(LogLevel.critical, message, details: details);
  }

  /// Log a trim job operation
  Future<void> logTrimJob({
    required String filePath,
    required double startTime,
    required double endTime,
    required String outputFileName,
    required List<String> outputFolders,
    required bool audioOnly,
    String? result,
    String? error,
  }) async {
    final details = {
      'filePath': filePath,
      'startTime': startTime.toString(),
      'endTime': endTime.toString(),
      'outputFileName': outputFileName,
      'outputFolders': outputFolders.join(', '),
      'audioOnly': audioOnly.toString(),
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    }.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    if (error != null) {
      await this.error('Trim job failed', details: details);
    } else {
      await this.info('Trim job completed', details: details);
    }
  }

  /// Write a log entry to the log file
  Future<void> _writeToLogFile(LogEntry entry) async {
    try {
      final logFilePath = await _appDirectoryService.getLogFilePath();
      final file = File(logFilePath);
      
      // Create the file if it doesn't exist
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      
      // Append the log entry to the file
      await file.writeAsString('${entry.toString()}\n', mode: FileMode.append);
    } catch (e) {
      // Just print to console if we can't write to the log file
      debugPrint('Error writing to log file: $e');
    }
  }

  /// Get the log file contents
  Future<String> getLogFileContents() async {
    try {
      final logFilePath = await _appDirectoryService.getLogFilePath();
      final file = File(logFilePath);
      
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'No log file found';
      }
    } catch (e) {
      debugPrint('Error reading log file: $e');
      return 'Error reading log file: $e';
    }
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    try {
      final logsDir = await _appDirectoryService.getLogsDirectory();
      final files = await logsDir.list().where((entity) => 
        entity is File && entity.path.endsWith('.txt')
      ).cast<File>().toList();
      
      // Sort by modification time (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      return files;
    } catch (e) {
      debugPrint('Error getting log files: $e');
      return [];
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/trim_job.dart';
import 'bundled_ffmpeg_service.dart';
import 'logging_service.dart';

/// Service class for handling FFmpeg operations
class FFmpegService {
  /// Singleton instance
  static final FFmpegService _instance = FFmpegService._internal();

  /// Factory constructor
  factory FFmpegService() => _instance;

  /// Bundled FFmpeg service
  final _bundledFFmpegService = BundledFFmpegService();

  /// Logging service
  final _loggingService = LoggingService();

  /// Internal constructor
  FFmpegService._internal() {
    // Check if FFmpeg is available when service is created
    checkFFmpegAvailability();
  }

  /// Whether FFmpeg is available
  bool _isFFmpegAvailable = false;
  
  /// Get whether FFmpeg is available
  bool get isFFmpegAvailable => _isFFmpegAvailable;

  /// Check if FFmpeg is available
  Future<bool> checkFFmpegAvailability() async {
    try {
      // First try the bundled FFmpeg
      _isFFmpegAvailable = await _bundledFFmpegService.isFFmpegAvailable();
      
      // If bundled FFmpeg is not available, try system FFmpeg as fallback
      if (!_isFFmpegAvailable) {
        final result = await Process.run('ffmpeg', ['-version']);
        _isFFmpegAvailable = result.exitCode == 0;
        if (_isFFmpegAvailable) {
          await _loggingService.info('System FFmpeg is available', details: result.stdout.toString().split('\n').first);
        } else {
          await _loggingService.warning('System FFmpeg is not available', details: result.stderr.toString());
        }
      }
      
      return _isFFmpegAvailable;
    } catch (e) {
      await _loggingService.error('Error checking FFmpeg availability', details: e.toString());
      _isFFmpegAvailable = false;
      return false;
    }
  }

  /// Process a trim job using FFmpeg
  /// 
  /// Returns a stream of progress updates (0.0 to 1.0)
  Stream<double> processTrimJob(TrimJob job) {
    final controller = StreamController<double>();
    
    _processTrimJobInternal(job, controller)
        .then((_) => controller.close())
        .catchError((error) {
          _loggingService.error('Error processing trim job', details: error.toString());
          controller.addError(error);
          controller.close();
        });
    
    return controller.stream;
  }

  /// Internal method to process a trim job
  Future<void> _processTrimJobInternal(
    TrimJob job, 
    StreamController<double> controller
  ) async {
    try {
      // Check if FFmpeg is available
      if (!_isFFmpegAvailable && !await checkFFmpegAvailability()) {
        throw Exception('FFmpeg is not available. Please check the application installation.');
      }

      // Get the FFmpeg executable path
      String ffmpegCommand = 'ffmpeg';
      try {
        // Try to get the bundled FFmpeg path
        ffmpegCommand = await _bundledFFmpegService.getFFmpegPath();
      } catch (e) {
        // If bundled FFmpeg fails, fall back to system FFmpeg
        await _loggingService.warning('Falling back to system FFmpeg', details: e.toString());
      }

      // Log the trim job start
      await _loggingService.info('Starting trim job', details: 
        'File: ${job.filePath}\n'
        'Start: ${job.startTime}s\n'
        'End: ${job.endTime}s\n'
        'Output: ${job.outputFileName}\n'
        'Folders: ${job.outputFolders.join(', ')}\n'
        'Audio only: ${job.audioOnly}'
      );

      for (final folder in job.outputFolders) {
        var outputFilePath = '$folder/${job.outputFileName}.mp4';
        
        // Create output directory if it doesn't exist
        final directory = Directory(folder);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          await _loggingService.info('Created output directory', details: folder);
        }

        // Format start and end times for FFmpeg
        final start = Duration(milliseconds: (job.startTime * 1000).toInt());
        final end = Duration(milliseconds: (job.endTime * 1000).toInt());
        
        // Build FFmpeg command
        final List<String> commandArgs = [
          '-y', // Automatically overwrite output file if it exists
          '-i', job.filePath,
          '-ss', _formatDuration(start),
          '-to', _formatDuration(end),
        ];
        
        // Add audio-only flag if needed
        if (job.audioOnly) {
          commandArgs.addAll(['-vn', '-acodec', 'copy']);
          // Change extension for audio-only output
          outputFilePath = outputFilePath.replaceAll('.mp4', '.m4a');
        } else {
          commandArgs.addAll(['-c', 'copy']);
        }
        
        // Add output file path
        commandArgs.add(outputFilePath);

        await _loggingService.info('Running FFmpeg command', details: '$ffmpegCommand ${commandArgs.join(' ')}');

        // Start FFmpeg process
        final process = await Process.start(ffmpegCommand, commandArgs);

        // Handle stdout
        process.stdout.transform(utf8.decoder).listen((data) {
          _loggingService.debug('FFmpeg stdout', details: data);
          // Parse FFmpeg output to update progress
          _parseProgressFromOutput(data, start, end, controller);
        });

        // Handle stderr
        process.stderr.transform(utf8.decoder).listen((data) {
          _loggingService.debug('FFmpeg stderr', details: data);
          // FFmpeg outputs progress information to stderr
          _parseProgressFromOutput(data, start, end, controller);
        });

        // Wait for process to complete
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          await _loggingService.error('FFmpeg process failed', details: 'Exit code: $exitCode');
          throw Exception('FFmpeg exited with code $exitCode');
        }
        
        await _loggingService.info('FFmpeg process completed successfully', details: 'Output: $outputFilePath');
      }
      
      // All folders processed successfully
      controller.add(1.0);
      await _loggingService.info('Trim job completed successfully', details: 'File: ${job.filePath}');
    } catch (e) {
      await _loggingService.error('Error in _processTrimJobInternal', details: e.toString());
      controller.addError(e);
      rethrow;
    }
  }

  /// Parse progress information from FFmpeg output
  void _parseProgressFromOutput(
    String data, 
    Duration start, 
    Duration end, 
    StreamController<double> controller
  ) {
    try {
      // FFmpeg outputs time information in format "time=HH:MM:SS.MS"
      final timeMatch = RegExp(r'time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})').firstMatch(data);
      
      if (timeMatch != null) {
        final hours = int.parse(timeMatch.group(1)!);
        final minutes = int.parse(timeMatch.group(2)!);
        final seconds = int.parse(timeMatch.group(3)!);
        final milliseconds = int.parse(timeMatch.group(4)!) * 10; // Convert to milliseconds
        
        final currentTime = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        
        // Calculate progress as a percentage of the total duration
        final totalDuration = end.inMilliseconds - start.inMilliseconds;
        final elapsedDuration = currentTime.inMilliseconds;
        final progress = elapsedDuration / totalDuration;
        
        // Clamp progress between 0.0 and 1.0
        final clampedProgress = progress.clamp(0.0, 1.0);
        
        // Send progress update
        controller.add(clampedProgress);
      }
    } catch (e) {
      _loggingService.error('Error parsing FFmpeg output', details: e.toString());
    }
  }

  /// Format duration for FFmpeg (HH:MM:SS)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}

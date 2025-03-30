import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/trim_job.dart';

/// Service class for handling FFmpeg operations
class FFmpegService {
  /// Singleton instance
  static final FFmpegService _instance = FFmpegService._internal();

  /// Factory constructor
  factory FFmpegService() => _instance;

  /// Internal constructor
  FFmpegService._internal();

  /// Process a trim job using FFmpeg
  /// 
  /// Returns a stream of progress updates (0.0 to 1.0)
  Stream<double> processTrimJob(TrimJob job) {
    final controller = StreamController<double>();
    
    _processTrimJobInternal(job, controller)
        .then((_) => controller.close())
        .catchError((error) {
          print('Error processing trim job: $error');
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
      for (final folder in job.outputFolders) {
        final outputFilePath = '$folder/${job.outputFileName}.mp4';
        
        // Create output directory if it doesn't exist
        final directory = Directory(folder);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        // Format start and end times for FFmpeg
        final start = Duration(milliseconds: (job.startTime * 1000).toInt());
        final end = Duration(milliseconds: (job.endTime * 1000).toInt());
        
        // Build FFmpeg command
        final command = [
          'ffmpeg',
          '-y', // Automatically overwrite output file if it exists
          '-i', job.filePath,
          '-ss', _formatDuration(start),
          '-to', _formatDuration(end),
          if (job.audioOnly) '-an',
          '-c', 'copy',
          outputFilePath,
        ];

        // Start FFmpeg process
        final process = await Process.start(command[0], command.sublist(1));

        // Handle stdout
        process.stdout.transform(utf8.decoder).listen((data) {
          // Parse FFmpeg output to update progress
          _parseProgressFromOutput(data, start, end, controller);
        });

        // Handle stderr
        process.stderr.transform(utf8.decoder).listen((data) {
          // FFmpeg outputs progress information to stderr
          _parseProgressFromOutput(data, start, end, controller);
        });

        // Wait for process to complete
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          throw Exception('FFmpeg exited with code $exitCode');
        }
      }
      
      // All folders processed successfully
      controller.add(1.0);
    } catch (e) {
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
    final regex = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)');
    final match = regex.firstMatch(data);
    
    if (match != null) {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final milliseconds = int.parse(match.group(4)!);
      
      final currentTime = Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      ).inMilliseconds;

      final totalDuration = (end - start).inMilliseconds;
      final progress = currentTime / totalDuration;
      
      // Clamp progress between 0.0 and 1.0
      final clampedProgress = progress.clamp(0.0, 1.0);
      controller.add(clampedProgress);
    }
  }

  /// Format duration for FFmpeg (HH:MM:SS)
  String _formatDuration(Duration duration) {
    return duration.toString().split('.').first;
  }
}

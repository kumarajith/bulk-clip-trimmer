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
  
  /// Store FFmpeg output for debugging
  final Map<String, StringBuffer> _ffmpegOutputLogs = {};

  /// Track the last time we received a progress update
  int _lastProgressUpdateTime = 0;

  /// Whether FFmpeg is available
  bool _isFFmpegAvailable = false;
  
  /// Get whether FFmpeg is available
  bool get isFFmpegAvailable => _isFFmpegAvailable;

  /// Internal constructor
  FFmpegService._internal() {
    // Check if FFmpeg is available when service is created
    checkFFmpegAvailability();
  }

  /// Check if FFmpeg is available
  Future<bool> checkFFmpegAvailability() async {
    try {
      // Only use the bundled FFmpeg, no fallback to system FFmpeg
      _isFFmpegAvailable = await _bundledFFmpegService.isFFmpegAvailable();
      
      if (_isFFmpegAvailable) {
        await _loggingService.info('Bundled FFmpeg is available');
      } else {
        await _loggingService.warning(
          'Bundled FFmpeg is not available', 
          details: 'Please ensure ffmpeg.exe is in the assets/bin directory.'
        );
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
  /// If a controller is provided, it will be used to send progress updates.
  /// Otherwise, a new controller is created and its stream is returned.
  Future<void> processTrimJob(TrimJob job, [StreamController<double>? externalController]) async {
    final controller = externalController ?? StreamController<double>();
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      // Initialize the log for this job
      _ffmpegOutputLogs[jobId] = StringBuffer();
      
      // Start processing
      await _processTrimJobInternal(job, controller, jobId);
      
      // Ensure we send a final progress update of 1.0 when complete
      if (!controller.isClosed && externalController == null) {
        controller.add(1.0);
        controller.close();
      }
    } catch (e) {
      // Handle errors
      if (!controller.isClosed && externalController == null) {
        controller.addError(e);
        controller.close();
      }
      _loggingService.error('Error in processTrimJob', details: e.toString());
      rethrow;
    }
  }

  /// Get video duration using FFmpeg
  Future<Duration?> getVideoDuration(String filePath) async {
    try {
      await _loggingService.info('Getting video duration for: $filePath');
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        await _loggingService.error('Video file does not exist', details: filePath);
        return null;
      }
      await _loggingService.info('Video file exists, size: ${await file.length()} bytes');
      
      // Check if FFmpeg is available
      if (!_isFFmpegAvailable && !await checkFFmpegAvailability()) {
        final errorMsg = 'FFmpeg is not available. Please ensure ffmpeg.exe is in the assets/bin directory. '
          'You can download FFmpeg from https://ffmpeg.org/download.html (Windows builds).';
        await _loggingService.error('FFmpeg not available', details: errorMsg);
        throw Exception(errorMsg);
      }

      // Get the FFprobe executable path directly from BundledFFmpegService
      String ffprobePath;
      try {
        ffprobePath = await _bundledFFmpegService.getFFprobePath();
        await _loggingService.info('Using ffprobe at: $ffprobePath');
        
        // Check if ffprobe.exe exists
        final ffprobeFile = File(ffprobePath);
        if (!await ffprobeFile.exists()) {
          await _loggingService.error('ffprobe.exe does not exist at path', details: ffprobePath);
          throw Exception('ffprobe.exe not found at $ffprobePath');
        }
        await _loggingService.info('ffprobe.exe exists, size: ${await ffprobeFile.length()} bytes');
      } catch (e) {
        // If bundled FFprobe fails, provide a clear error message
        final errorMsg = 'FFprobe is not available: ${e.toString()}. '
          'Please ensure ffprobe.exe is in the assets/bin directory.';
        await _loggingService.error('FFprobe not available', details: errorMsg);
        throw Exception(errorMsg);
      }

      // Use FFprobe to get duration
      await _loggingService.info('Running ffprobe command', details: '$ffprobePath -i "$filePath" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1');
      
      final result = await Process.run(ffprobePath, [
        '-i', _normalizePath(filePath),
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
      ]);

      await _loggingService.info('ffprobe exit code: ${result.exitCode}');
      await _loggingService.info('ffprobe stdout: ${result.stdout}');
      await _loggingService.info('ffprobe stderr: ${result.stderr}');
      
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final durationInSeconds = double.tryParse(result.stdout.toString().trim());
        if (durationInSeconds != null) {
          final duration = Duration(milliseconds: (durationInSeconds * 1000).toInt());
          await _loggingService.info('Video duration determined', details: '${_formatDuration(duration)} (${durationInSeconds.toStringAsFixed(3)} sec)');
          return duration;
        } else {
          await _loggingService.error('Could not parse duration from ffprobe output', details: 'Output: "${result.stdout.toString().trim()}"');
        }
      } else {
        await _loggingService.error('Error getting video duration', 
            details: 'Exit code: ${result.exitCode}\nStderr: ${result.stderr}');
      }
      
      return null;
    } catch (e) {
      await _loggingService.error('Error getting video duration', details: e.toString());
      return null;
    }
  }

  /// Internal method to process a trim job
  Future<void> _processTrimJobInternal(TrimJob job, StreamController<double> controller, String jobId) async {
    try {
      // Validate the job parameters
      if (job.filePath.isEmpty) {
        throw Exception('Invalid file path');
      }

      if (job.outputFolders.isEmpty) {
        throw Exception('No output folders specified');
      }

      // Calculate duration in milliseconds
      final durationInSeconds = job.endTime - job.startTime;
      final durationMs = (durationInSeconds * 1000).round();

      if (durationMs <= 0) {
        throw Exception('Invalid duration: $durationMs ms');
      }

      // Send initial progress update
      controller.add(0.01); // Start at 1% to show something immediately
      
      // Create output folder if it doesn't exist
      for (final outputFolder in job.outputFolders) {
        final directory = Directory(outputFolder);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }

      // Validate start and end times
      if (job.startTime < 0) {
        throw Exception('Start time cannot be negative');
      }

      if (job.endTime <= job.startTime) {
        throw Exception('End time must be greater than start time');
      }

      // Log is already initialized in processTrimJob
      // No need to initialize it again here

      // Validate input file exists
      final inputFile = File(job.filePath);
      if (!await inputFile.exists()) {
        throw Exception('Input file does not exist: ${job.filePath}');
      }

      // Get video duration to validate trim points
      final videoDuration = await getVideoDuration(job.filePath);
      if (videoDuration == null) {
        throw Exception('Could not determine video duration for: ${job.filePath}');
      }

      // Validate trim points are within video duration
      final videoDurationMs = videoDuration.inMilliseconds;
      final videoDurationSec = videoDurationMs / 1000.0;
      final startTimeSec = job.startTime;
      final endTimeSec = job.endTime;

      // Log the trim job start with video duration info
      await _loggingService.info('Starting trim job', details: 
        'File: ${job.filePath}\n'
        'Video Duration: ${_formatDuration(videoDuration)} (${videoDurationSec.toStringAsFixed(3)} sec)\n'
        'Start: ${_formatDuration(job.startDuration)} (${startTimeSec.toStringAsFixed(3)} sec)\n'
        'End: ${_formatDuration(job.endDuration)} (${endTimeSec.toStringAsFixed(3)} sec)\n'
        'Output: ${job.outputFileName}\n'
        'Folders: ${job.outputFolders.join(', ')}\n'
        'Audio only: ${job.audioOnly}'
      );

      // Validate start time is within video duration
      if (startTimeSec >= videoDurationSec) {
        throw Exception('Start time (${startTimeSec.toStringAsFixed(3)} sec) ' +
                        'exceeds video duration (${videoDurationSec.toStringAsFixed(3)} sec)');
      }

      // Validate end time is within video duration and after start time
      TrimJob validatedJob = job;
      if (endTimeSec > videoDurationSec) {
        await _loggingService.warning(
          'End time exceeds video duration, clamping to video end', 
          details: 'End time: ${endTimeSec.toStringAsFixed(3)} sec, ' +
                  'Video duration: ${videoDurationSec.toStringAsFixed(3)} sec');
        // Clamp end time to video duration
        validatedJob = job.copyWith(endTime: videoDurationSec);
      }

      // Ensure end time is greater than start time
      if (validatedJob.endTime <= validatedJob.startTime) {
        throw Exception('End time must be greater than start time');
      }

      for (final folder in validatedJob.outputFolders) {
        var outputFilePath = '$folder/${validatedJob.outputFileName}';
        
        // Add extension if not already present
        if (!validatedJob.audioOnly && !outputFilePath.toLowerCase().endsWith('.mp4')) {
          outputFilePath += '.mp4';
        } else if (validatedJob.audioOnly && !outputFilePath.toLowerCase().endsWith('.m4a')) {
          outputFilePath += '.m4a';
        }
        
        // Create output directory if it doesn't exist
        final directory = Directory(folder);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          await _loggingService.info('Created output directory', details: folder);
        }

        // Calculate duration in seconds (clamped to video duration)
        final durationInSeconds = validatedJob.endTime - validatedJob.startTime;
        final durationMs = (durationInSeconds * 1000).round(); // Fix: Round to nearest integer
        
        // Build FFmpeg command
        final List<String> commandArgs = [
          '-y', // Automatically overwrite output file if it exists
          '-progress', 'pipe:1', // Output progress information to stdout in a machine-readable format
          '-i', _normalizePath(validatedJob.filePath), // Input file
          '-ss', _formatDuration(validatedJob.startDuration), // Start time
          '-t', _formatDuration(Duration(milliseconds: durationMs)), // Duration
        ];
        
        // Add audio-only flag if needed
        if (validatedJob.audioOnly) {
          commandArgs.addAll([
            '-vn', // No video
            '-c:a', 'aac', // AAC audio codec
            '-b:a', '192k', // Audio bitrate
          ]);
        } else {
          // For video, use a more compatible encoding method
          commandArgs.addAll([
            '-c:v', 'libx264', // Use H.264 codec for video
            '-preset', 'medium', // Balance between quality and speed
            '-crf', '23', // Constant Rate Factor (quality setting, lower is better)
            '-c:a', 'aac', // Use AAC for audio
            '-b:a', '128k', // Audio bitrate
            '-pix_fmt', 'yuv420p', // Standard pixel format for compatibility
          ]);
        }
        
        // Add output file as the last argument
        commandArgs.add(_normalizePath(outputFilePath));
        
        // Log the command for debugging - use escaped paths for the log
        final logCommandArgs = commandArgs.toList();
        // Replace the input and output file paths with escaped versions for logging
        for (int i = 0; i < logCommandArgs.length; i++) {
          if (i > 0 && (logCommandArgs[i-1] == '-i' || i == logCommandArgs.length - 1)) {
            logCommandArgs[i] = _escapeFilePath(logCommandArgs[i]);
          }
        }
        final commandString = '${await _bundledFFmpegService.getFFmpegPath()} ${logCommandArgs.join(' ')}';
        await _loggingService.info('Running FFmpeg command', details: commandString);
        _ffmpegOutputLogs[jobId]!.writeln('Command: $commandString');

        // Start FFmpeg process
        final ffmpegProcess = await Process.start(
          await _bundledFFmpegService.getFFmpegPath(),
          commandArgs,
          environment: {'PATH': _getPathEnvironment()},
        );

        // Initialize progress tracking timestamp
        _lastProgressUpdateTime = DateTime.now().millisecondsSinceEpoch;

        // Set up process output handling with more frequent updates
        final stdoutSubscription = ffmpegProcess.stdout.transform(utf8.decoder).listen((data) {
          _ffmpegOutputLogs[jobId]!.write(data);
          _parseProgressFromOutput(
            data,
            validatedJob.startTime,
            validatedJob.endTime,
            controller,
          );
        });

        final stderrSubscription = ffmpegProcess.stderr.transform(utf8.decoder).listen((data) {
          _ffmpegOutputLogs[jobId]!.writeln('STDERR: $data');
          // Also check stderr for progress information in case FFmpeg outputs there
          if (data.contains('time=') || data.contains('frame=')) {
            _parseProgressFromOutput(
              data,
              validatedJob.startTime,
              validatedJob.endTime,
              controller,
            );
          }
        });

        // Send periodic progress updates even if FFmpeg doesn't report them
        // This helps ensure the UI shows some activity
        double lastReportedProgress = 0.01;
        final progressTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
          // Only send periodic updates if we haven't seen progress in a while
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          if (currentTime - _lastProgressUpdateTime > 2000) {
            // If no updates for 2 seconds, send a small increment to show activity
            if (lastReportedProgress > 0.01 && lastReportedProgress < 0.95) {
              // Add a tiny increment to show activity (max 0.5% increase)
              final newProgress = (lastReportedProgress + 0.005).clamp(0.01, 0.95);
              controller.add(newProgress);
              lastReportedProgress = newProgress;
              _loggingService.debug('Sending heartbeat progress update', 
                  details: 'Progress: ${(newProgress * 100).toStringAsFixed(1)}%');
            }
            _lastProgressUpdateTime = currentTime; // Reset the timer
          }
        });

        // Wait for process to complete
        final exitCode = await ffmpegProcess.exitCode;
        
        // Clean up subscriptions and timer
        progressTimer.cancel();
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        
        // Check if output file exists and has content
        final outputFile = File(outputFilePath);
        final fileExists = await outputFile.exists();
        final fileSize = fileExists ? await outputFile.length() : 0;
        
        _ffmpegOutputLogs[jobId]!.writeln('Exit code: $exitCode');
        _ffmpegOutputLogs[jobId]!.writeln('Output file exists: $fileExists');
        _ffmpegOutputLogs[jobId]!.writeln('Output file size: $fileSize bytes');
        
        if (exitCode != 0) {
          final errorMessage = 'FFmpeg exited with code $exitCode';
          await _loggingService.error('FFmpeg process failed', 
              details: 'Exit code: $exitCode\nOutput log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
          throw Exception(errorMessage);
        }
        
        if (fileSize < 1000) { // Less than 1KB is suspicious
          final errorMessage = 'Output file is too small (${fileSize} bytes), likely corrupted';
          await _loggingService.error('FFmpeg output file too small', 
              details: '$errorMessage\nOutput log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
          throw Exception(errorMessage);
        }
        
        // Send a progress update to indicate this folder is complete
        controller.add(0.99); // Use 0.99 to indicate near completion for this folder
        
        await _loggingService.info('FFmpeg process completed successfully', 
            details: 'Output: $outputFilePath\nFile size: $fileSize bytes');
      }
      
      // All folders processed successfully
      controller.add(1.0);
      await _loggingService.info('Trim job completed successfully', 
          details: 'File: ${job.filePath}\nFull log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
      
      // Clean up log after successful completion
      _ffmpegOutputLogs.remove(jobId);
    } catch (e) {
      await _loggingService.error('Error in _processTrimJobInternal', details: e.toString());
      controller.addError(e);
      rethrow;
    }
  }

  /// Parse progress information from FFmpeg output
  void _parseProgressFromOutput(
    String data, 
    double startTimeSeconds,
    double endTimeSeconds,
    StreamController<double> controller
  ) {
    try {
      // Update last progress time to track activity
      _lastProgressUpdateTime = DateTime.now().millisecondsSinceEpoch;
      
      // Log raw progress data for debugging at a lower level
      _loggingService.debug('Raw FFmpeg progress data', details: data.trim());
      
      // Calculate total duration in seconds
      final durationSeconds = endTimeSeconds - startTimeSeconds;
      if (durationSeconds <= 0) {
        _loggingService.error('Invalid duration', details: 'Duration must be positive');
        return;
      }
      
      // Try different methods to extract progress information
      double? progressValue;
      
      // 1. Try to find out_time_ms (milliseconds)
      final outTimeMs = RegExp(r'out_time_ms=(\d+)').firstMatch(data);
      if (outTimeMs != null) {
        final ms = int.parse(outTimeMs.group(1)!);
        final seconds = ms / 1000.0;
        final adjustedSeconds = seconds - startTimeSeconds;
        progressValue = (adjustedSeconds / durationSeconds).clamp(0.0, 1.0);
        _loggingService.debug('Progress from out_time_ms', 
            details: 'Time: ${seconds.toStringAsFixed(2)}s, Progress: ${(progressValue * 100).toStringAsFixed(1)}%');
        controller.add(progressValue);
        return;
      }
      
      // 2. Try to find out_time (HH:MM:SS.mmm format)
      final outTime = RegExp(r'out_time=([\d:]+\.?\d*)').firstMatch(data);
      if (outTime != null) {
        final timeStr = outTime.group(1)!;
        final parts = timeStr.split(':');
        
        if (parts.length >= 3) {
          double hours = 0, minutes = 0, seconds = 0;
          try {
            hours = double.parse(parts[0]);
            minutes = double.parse(parts[1]);
            // Handle seconds with potential decimal part
            seconds = double.parse(parts[2]);
          } catch (e) {
            _loggingService.error('Error parsing time parts', details: e.toString());
          }
          
          final totalSeconds = hours * 3600 + minutes * 60 + seconds;
          final adjustedSeconds = totalSeconds - startTimeSeconds;
          progressValue = (adjustedSeconds / durationSeconds).clamp(0.0, 1.0);
          _loggingService.debug('Progress from out_time', 
              details: 'Time: ${totalSeconds.toStringAsFixed(2)}s, Progress: ${(progressValue * 100).toStringAsFixed(1)}%');
          controller.add(progressValue);
          return;
        }
      }
      
      // 3. Try to find time= (another common format)
      final timeMatch = RegExp(r'time=([\d:]+\.?\d*)').firstMatch(data);
      if (timeMatch != null) {
        final timeStr = timeMatch.group(1)!;
        final parts = timeStr.split(':');
        
        if (parts.length >= 3) {
          double hours = 0, minutes = 0, seconds = 0;
          try {
            hours = double.parse(parts[0]);
            minutes = double.parse(parts[1]);
            // Handle seconds with potential decimal part
            seconds = double.parse(parts[2]);
          } catch (e) {
            _loggingService.error('Error parsing time parts', details: e.toString());
          }
          
          final totalSeconds = hours * 3600 + minutes * 60 + seconds;
          final adjustedSeconds = totalSeconds - startTimeSeconds;
          progressValue = (adjustedSeconds / durationSeconds).clamp(0.0, 1.0);
          _loggingService.debug('Progress from time=', 
              details: 'Time: ${totalSeconds.toStringAsFixed(2)}s, Progress: ${(progressValue * 100).toStringAsFixed(1)}%');
          controller.add(progressValue);
          return;
        }
      }
      
      // 4. Try to find frame= and fps= to estimate progress
      final frameMatch = RegExp(r'frame=\s*(\d+)').firstMatch(data);
      final fpsMatch = RegExp(r'fps=\s*(\d+(?:\.\d+)?)').firstMatch(data);
      final speedMatch = RegExp(r'speed=\s*(\d+(?:\.\d+)?)x').firstMatch(data);
      
      if (frameMatch != null && fpsMatch != null) {
        final frame = int.parse(frameMatch.group(1)!);
        final fps = double.parse(fpsMatch.group(1)!);
        
        // If we have speed information, log it for debugging
        double speed = 1.0;
        if (speedMatch != null) {
          speed = double.parse(speedMatch.group(1)!);
          _loggingService.debug('FFmpeg processing speed', details: '${speed}x');
        }
        
        if (fps > 0) {
          // Estimate current time based on frame and fps
          final estimatedSeconds = frame / fps;
          final adjustedSeconds = estimatedSeconds - startTimeSeconds;
          progressValue = (adjustedSeconds / durationSeconds).clamp(0.0, 1.0);
          _loggingService.debug('Progress from frame/fps', 
              details: 'Frame: $frame, FPS: $fps, Time: ${estimatedSeconds.toStringAsFixed(2)}s, Progress: ${(progressValue * 100).toStringAsFixed(1)}%');
          controller.add(progressValue);
          return;
        }
      }
      
      // If we got here, we couldn't parse progress from any known format
      _loggingService.debug('Could not parse progress from output', details: data.trim());
      
    } catch (e) {
      _loggingService.error('Error parsing progress', details: e.toString());
    }
  }

  /// Normalize a file path for use in FFmpeg arguments
  String _normalizePath(String path) {
    // Just normalize slashes for consistency, no quoting needed
    // Process.run will handle the quoting internally
    return path.replaceAll('\\', '/');
  }

  /// Escape a file path for use in FFmpeg command string
  /// Only use this when building a command string, not when passing arguments to Process.run
  String _escapeFilePath(String path) {
    // First, normalize all slashes to forward slashes for consistency
    String normalizedPath = path.replaceAll('\\', '/');
    
    // For Windows paths, we need to ensure proper quoting
    // If the path already has quotes, don't add more
    if (normalizedPath.startsWith('"') && normalizedPath.endsWith('"')) {
      return normalizedPath;
    }
    
    // Add quotes to handle spaces in paths
    return '"$normalizedPath"';
  }

  /// Format duration for FFmpeg (HH:MM:SS.mmm)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  String _getPathEnvironment() {
    final path = Platform.environment['PATH'];
    if (path != null) {
      return path;
    } else {
      return '';
    }
  }
}

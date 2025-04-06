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
        '-i', filePath,
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
  Future<void> _processTrimJobInternal(
    TrimJob job, 
    StreamController<double> controller
  ) async {
    try {
      // Check if FFmpeg is available
      if (!_isFFmpegAvailable && !await checkFFmpegAvailability()) {
        throw Exception(
          'FFmpeg is not available. Please ensure ffmpeg.exe is in the assets/bin directory. '
          'You can download FFmpeg from https://ffmpeg.org/download.html (Windows builds).'
        );
      }

      // Get the FFmpeg executable path
      String ffmpegCommand;
      try {
        // Try to get the bundled FFmpeg path
        ffmpegCommand = await _bundledFFmpegService.getFFmpegPath();
      } catch (e) {
        // If bundled FFmpeg fails, provide a clear error message
        final errorMsg = 'FFmpeg is not available: ${e.toString()}. '
          'Please ensure ffmpeg.exe is in the assets/bin directory.';
        await _loggingService.error('FFmpeg not available', details: errorMsg);
        throw Exception(errorMsg);
      }

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

      // Create a unique ID for this job to track its output
      final jobId = '${DateTime.now().millisecondsSinceEpoch}_${job.filePath.hashCode}';
      _ffmpegOutputLogs[jobId] = StringBuffer();

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
          '-i', validatedJob.filePath,
          '-ss', _formatDuration(validatedJob.startDuration),
          '-t', _formatDuration(Duration(milliseconds: durationMs)),
        ];
        
        // Add audio-only flag if needed
        if (validatedJob.audioOnly) {
          commandArgs.addAll(['-vn', '-acodec', 'aac', '-b:a', '192k']);
        } else {
          // For video, use a more compatible encoding method instead of just copying
          commandArgs.addAll([
            '-c:v', 'libx264', // Use H.264 codec for video
            '-preset', 'medium', // Balance between quality and speed
            '-c:a', 'aac', // Use AAC for audio
            '-b:a', '128k', // Audio bitrate
            '-pix_fmt', 'yuv420p', // Standard pixel format for compatibility
          ]);
        }
        
        // Add output file path
        commandArgs.add(outputFilePath);

        final commandString = '$ffmpegCommand ${commandArgs.join(' ')}';
        await _loggingService.info('Running FFmpeg command', details: commandString);
        _ffmpegOutputLogs[jobId]!.writeln('Command: $commandString');

        // Start FFmpeg process
        final process = await Process.start(ffmpegCommand, commandArgs);

        // Handle stdout
        process.stdout.transform(utf8.decoder).listen((data) {
          _ffmpegOutputLogs[jobId]!.writeln('STDOUT: $data');
          _loggingService.debug('FFmpeg stdout', details: data);
          // Parse FFmpeg output to update progress
          _parseProgressFromOutput(data, validatedJob.startTime, validatedJob.endTime, controller);
        });

        // Handle stderr
        process.stderr.transform(utf8.decoder).listen((data) {
          _ffmpegOutputLogs[jobId]!.writeln('STDERR: $data');
          _loggingService.debug('FFmpeg stderr', details: data);
          // FFmpeg outputs progress information to stderr
          _parseProgressFromOutput(data, validatedJob.startTime, validatedJob.endTime, controller);
        });

        // Wait for process to complete
        final exitCode = await process.exitCode;
        
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
        
        await _loggingService.info('FFmpeg process completed successfully', 
            details: 'Output: $outputFilePath\nFile size: $fileSize bytes');
      }
      
      // All folders processed successfully
      await _loggingService.info('Adding final progress 1.0 to stream', details: 'File: ${job.filePath}');
      controller.add(1.0);
      await _loggingService.info('Trim job completed successfully', 
          details: 'File: ${job.filePath}\nFull log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
      
      // Clean up log after successful completion
      _ffmpegOutputLogs.remove(jobId);
    } catch (e) {
      await _loggingService.error('Adding error to stream', details: 'File: ${job.filePath}, Error: ${e.toString()}');
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
      // Log raw data received from FFmpeg stderr/stdout
      _loggingService.debug('FFmpeg Raw Output', details: data.trim());
          
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
        
        // Calculate total duration in milliseconds
        final totalDurationMs = (endTimeSeconds - startTimeSeconds) * 1000;
        final elapsedDurationMs = currentTime.inMilliseconds;
        
        // Calculate progress as a percentage of the total duration
        final progress = totalDurationMs > 0 ? elapsedDurationMs / totalDurationMs : 0.0; // Avoid division by zero
        
        // Clamp progress between 0.0 and 1.0
        final clampedProgress = progress.clamp(0.0, 1.0);
        
        // Send progress update
        _loggingService.debug('FFmpeg progress update', details: 'Raw: $progress, Clamped: $clampedProgress, CurrentTime: ${currentTime.inMilliseconds}ms, TotalDuration: ${totalDurationMs}ms');
        controller.add(clampedProgress);
      }
    } catch (e) {
      _loggingService.error('Error parsing FFmpeg output', details: e.toString());
    }
  }

  /// Format duration for FFmpeg (HH:MM:SS.mmm)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    
    return '$hours:$minutes:$seconds.$milliseconds';
  }
}

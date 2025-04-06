import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  
  /// Store FFmpeg output logs for debugging
  final Map<String, StringBuffer> _ffmpegOutputLogs = {};

  /// Map of active FFmpeg processes by job ID
  final Map<String, Process> _activeProcesses = {};
  
  /// Map of temporary directories by job ID
  final Map<String, Directory> _tempDirs = {};
  
  /// Map of progress timers by job ID
  final Map<String, Timer> _progressTimers = {};

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
        final errorMsg = 'FFmpeg is not available. Please ensure ffmpeg.exe is in the assets/bin directory.';
        await _loggingService.error('FFmpeg not available', details: errorMsg);
        throw Exception(errorMsg);
      }

      // Get the FFprobe executable path
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

  /// Process a trim job and return a stream of progress updates
  Stream<double> processTrimJob(TrimJob job) {
    final jobId = job.id ?? _generateJobId(); // Use the job ID from the TrimJob object or generate a new one
    final controller = StreamController<double>();
    
    _processTrimJobInternal(job, controller, jobId).then((_) {
      if (!controller.isClosed) {
        controller.add(1.0);
        _loggingService.info('Trim job completed successfully', 
          details: 'ID: $jobId, Path: ${job.filePath}');
      }
    }).catchError((error) {
      if (!controller.isClosed) {
        _loggingService.error('Error processing trim job', details: error.toString());
        controller.addError(error);
      }
    }).whenComplete(() {
      _cleanupResources(jobId);
      if (!controller.isClosed) {
        controller.close();
      }
    });
    
    return controller.stream;
  }

  /// Cancel a specific FFmpeg process
  Future<void> cancelProcess(String jobId) async {
    await _loggingService.info('Attempting to cancel FFmpeg process', details: 'Job ID: $jobId');
    
    // Kill the process if it exists
    final process = _activeProcesses[jobId];
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
        await _loggingService.info('Sent termination signal to FFmpeg process', details: 'Job ID: $jobId');
      } catch (e) {
        await _loggingService.error('Failed to terminate FFmpeg process', details: 'Job ID: $jobId, Error: $e');
      }
    }
    
    // Clean up resources
    _cleanupResources(jobId);
  }

  /// Clean up resources for a job
  Future<void> _cleanupResources(String jobId) async {
    // Cancel progress timer if it exists
    final timer = _progressTimers.remove(jobId);
    timer?.cancel();
    
    // Remove process reference
    _activeProcesses.remove(jobId);
    
    // Clean up temp directory
    final tempDir = _tempDirs.remove(jobId);
    if (tempDir != null) {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
          await _loggingService.debug('Deleted temporary directory', details: 'Path: ${tempDir.path}');
        }
      } catch (e) {
        await _loggingService.error('Failed to delete temporary directory', details: 'Path: ${tempDir.path}, Error: $e');
      }
    }
    
    // Clean up logs
    _ffmpegOutputLogs.remove(jobId);
    
    await _loggingService.info('Cleaned up resources for job', details: 'Job ID: $jobId');
  }

  /// Internal method to process a trim job
  Future<void> _processTrimJobInternal(
    TrimJob job, 
    StreamController<double> controller,
    String jobId
  ) async {
    try {
      // Initialize output log
      _ffmpegOutputLogs[jobId] = StringBuffer();
      
      // Check if FFmpeg is available
      if (!_isFFmpegAvailable && !await checkFFmpegAvailability()) {
        throw Exception(
          'FFmpeg is not available. Please ensure ffmpeg.exe is in the assets/bin directory.'
        );
      }

      // Get the FFmpeg executable path
      String ffmpegPath;
      try {
        ffmpegPath = await _bundledFFmpegService.getFFmpegPath();
      } catch (e) {
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

      // Validate trim points
      final videoDurationSec = videoDuration.inMilliseconds / 1000.0;
      final startTimeSec = job.startTime;
      final endTimeSec = job.endTime;

      // Log the trim job start
      await _loggingService.info('Starting trim job', details: 
        'File: ${job.filePath}\n'
        'Video Duration: ${_formatDuration(videoDuration)} (${videoDurationSec.toStringAsFixed(3)} sec)\n'
        'Start: ${_formatDuration(job.startDuration)} (${startTimeSec.toStringAsFixed(3)} sec)\n'
        'End: ${_formatDuration(job.endDuration)} (${endTimeSec.toStringAsFixed(3)} sec)');
    
      // Validate start time
      if (startTimeSec >= videoDurationSec) {
        throw Exception('Start time (${startTimeSec.toStringAsFixed(3)} sec) ' +
                        'exceeds video duration (${videoDurationSec.toStringAsFixed(3)} sec)');
      }

      // Validate and potentially adjust end time
      TrimJob validatedJob = job;
      if (endTimeSec > videoDurationSec) {
        await _loggingService.warning(
          'End time exceeds video duration, clamping to video end', 
          details: 'End time: ${endTimeSec.toStringAsFixed(3)} sec, ' +
                  'Video duration: ${videoDurationSec.toStringAsFixed(3)} sec');
        validatedJob = job.copyWith(endTime: videoDurationSec);
      }

      // Ensure end time is greater than start time
      if (validatedJob.endTime <= validatedJob.startTime) {
        throw Exception('End time must be greater than start time');
      }

      // Create temporary directory for progress tracking
      final tempDir = await Directory.systemTemp.createTemp('ffmpeg_progress');
      _tempDirs[jobId] = tempDir;
      final progressFile = File('${tempDir.path}/progress.txt');
      
      // Send initial progress update
      controller.add(0.01);

      // Process each output folder
      for (final folder in validatedJob.outputFolders) {
        await _processForFolder(
          validatedJob, 
          folder, 
          ffmpegPath, 
          progressFile, 
          controller, 
          jobId
        );
      }
      
      // All folders processed successfully
      await _loggingService.info('All folders processed for job', details: 'Job ID: $jobId');
      
    } catch (e) {
      await _loggingService.error('Error in _processTrimJobInternal', details: 'Job ID: $jobId, Error: $e');
      throw e;
    }
  }

  /// Process the job for a specific output folder
  Future<void> _processForFolder(
    TrimJob job,
    String folder,
    String ffmpegPath,
    File progressFile,
    StreamController<double> controller,
    String jobId
  ) async {
    var outputFilePath = '$folder/${job.outputFileName}';
    
    // Add extension if not already present
    if (!job.audioOnly && !outputFilePath.toLowerCase().endsWith('.mp4')) {
      outputFilePath += '.mp4';
    } else if (job.audioOnly && !outputFilePath.toLowerCase().endsWith('.m4a')) {
      outputFilePath += '.m4a';
    }
    
    // Create output directory if it doesn't exist
    final directory = Directory(folder);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      await _loggingService.info('Created output directory', details: folder);
    }

    // Calculate duration in seconds
    final durationInSeconds = job.endTime - job.startTime;
    final durationMs = (durationInSeconds * 1000).round();
    
    // Build FFmpeg command
    final List<String> commandArgs = [
      '-y',
      '-i', job.filePath,
      '-ss', _formatDuration(job.startDuration),
      '-t', _formatDuration(Duration(milliseconds: durationMs)),
      '-progress', progressFile.path,
      '-stats',
    ];
    
    // Add audio-only or video encoding options
    if (job.audioOnly) {
      commandArgs.addAll(['-vn', '-acodec', 'aac', '-b:a', '192k']);
    } else {
      commandArgs.addAll([
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-pix_fmt', 'yuv420p',
      ]);
    }
    
    // Add output file path
    commandArgs.add(outputFilePath);

    final commandString = '$ffmpegPath ${commandArgs.join(' ')}';
    await _loggingService.info('Running FFmpeg command', details: commandString);
    _ffmpegOutputLogs[jobId]!.writeln('Command: $commandString');

    // Start FFmpeg process
    final process = await Process.start(ffmpegPath, commandArgs);
    _activeProcesses[jobId] = process;

    // Set up progress timer
    final progressTimer = Timer.periodic(Duration(milliseconds: 50), (timer) async {
      try {
        if (await progressFile.exists()) {
          final content = await progressFile.readAsString();
          _parseProgressFile(
            content, 
            job.startTime, 
            job.endTime, 
            controller, 
            job.audioOnly, 
            jobId
          );
          
          // Check for completion
          if (content.contains('progress=end')) {
            timer.cancel();
            await _loggingService.debug('Progress file indicates completion', details: 'Job ID: $jobId');
          }
        }
      } catch (e) {
        // Ignore file access errors
      }
    });
    _progressTimers[jobId] = progressTimer;

    // Handle stdout
    process.stdout.transform(utf8.decoder).listen((data) {
      _ffmpegOutputLogs[jobId]!.writeln('STDOUT: $data');
      _loggingService.debug('FFmpeg stdout', details: 'Job ID: $jobId, Data: $data');
    });

    // Handle stderr
    process.stderr.transform(utf8.decoder).listen((data) {
      _ffmpegOutputLogs[jobId]!.writeln('STDERR: $data');
      _loggingService.debug('FFmpeg stderr', details: 'Job ID: $jobId, Data: $data');
    });

    // Wait for process to complete
    final exitCode = await process.exitCode;
    
    // Cancel timer
    progressTimer.cancel();
    _progressTimers.remove(jobId);
    
    // Handle audio-only progress update
    if (job.audioOnly) {
      controller.add(0.99);
      await _loggingService.info('Audio job process completed', details: 'Job ID: $jobId, Exit code: $exitCode');
    }
    
    // Validate output
    final outputFile = File(outputFilePath);
    final fileExists = await outputFile.exists();
    final fileSize = fileExists ? await outputFile.length() : 0;
    
    _ffmpegOutputLogs[jobId]!.writeln('Exit code: $exitCode');
    _ffmpegOutputLogs[jobId]!.writeln('Output file exists: $fileExists');
    _ffmpegOutputLogs[jobId]!.writeln('Output file size: $fileSize bytes');
    
    // Check for errors
    if (exitCode != 0) {
      final errorMessage = 'FFmpeg exited with code $exitCode';
      await _loggingService.error('FFmpeg process failed', 
          details: 'Job ID: $jobId, Exit code: $exitCode\nOutput log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
      throw Exception(errorMessage);
    }
    
    if (fileSize < 1000) {
      final errorMessage = 'Output file is too small (${fileSize} bytes), likely corrupted';
      await _loggingService.error('FFmpeg output file too small', 
          details: 'Job ID: $jobId, $errorMessage\nOutput log:\n${_ffmpegOutputLogs[jobId]!.toString()}');
      throw Exception(errorMessage);
    }
    
    await _loggingService.info('FFmpeg process completed for folder', 
        details: 'Job ID: $jobId, Output: $outputFilePath, File size: $fileSize bytes');
  }

  /// Parse progress information from progress file
  void _parseProgressFile(
    String content,
    double startTimeSeconds,
    double endTimeSeconds,
    StreamController<double> controller,
    bool isAudioOnly,
    String jobId
  ) {
    try {
      // For audio-only jobs, use simplified progress reporting
      if (isAudioOnly) {
        if (content.contains('progress=continue')) {
          controller.add(0.5);
        }
        return;
      }
      
      // Calculate target duration
      final targetDurationSec = endTimeSeconds - startTimeSeconds;
      
      // Try to get time from progress info
      double? outputTimeSec = _extractTimeFromProgress(content);
      
      if (outputTimeSec != null && outputTimeSec > 0) {
        // Calculate progress as a percentage of target duration
        final progress = (outputTimeSec / targetDurationSec).clamp(0.0, 0.99);
        
        if ((progress * 100).round() % 5 == 0) { // Log every 5%
          _loggingService.info('Progress update', 
              details: 'Job ID: $jobId, Time: ${outputTimeSec.toStringAsFixed(2)}s / ${targetDurationSec.toStringAsFixed(2)}s = ${(progress * 100).toStringAsFixed(1)}%');
        }
        
        controller.add(progress);
      } else if (content.contains('frame=') && !content.contains('frame=0')) {
        // Processing has started but we don't know exact progress
        controller.add(0.01);
      }
    } catch (e) {
      _loggingService.error('Error parsing FFmpeg progress', details: 'Job ID: $jobId, Error: $e');
    }
  }

  /// Extract time in seconds from progress file content
  double? _extractTimeFromProgress(String content) {
    // Try microseconds first (most accurate)
    final msRegex = RegExp(r'out_time_ms=([0-9]+)');
    final msMatches = msRegex.allMatches(content).toList();
    
    if (msMatches.isNotEmpty) {
      final msMatch = msMatches.last;
      final msValue = msMatch.group(1)!;
      final timeMs = int.tryParse(msValue);
      
      if (timeMs != null && timeMs > 0) {
        return timeMs / 1000000.0; // Convert microseconds to seconds
      }
    }
    
    // Try formatted time as fallback
    final timeRegex = RegExp(r'out_time=([0-9]+):([0-9]+):([0-9]+\.[0-9]+)');
    final timeMatches = timeRegex.allMatches(content).toList();
    
    if (timeMatches.isNotEmpty) {
      final timeMatch = timeMatches.last;
      
      try {
        final hours = int.parse(timeMatch.group(1)!);
        final minutes = int.parse(timeMatch.group(2)!);
        final seconds = double.parse(timeMatch.group(3)!);
        
        return (hours * 3600) + (minutes * 60) + seconds;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  /// Format duration for FFmpeg (HH:MM:SS.mmm)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    
    return '$hours:$minutes:$seconds.$milliseconds';
  }
  
  /// Dispose all resources
  void dispose() {
    // Cancel all active processes
    for (final entry in _activeProcesses.entries) {
      try {
        entry.value.kill(ProcessSignal.sigterm);
      } catch (e) {
        // Ignore errors when killing processes
      }
    }
    
    // Cancel all timers
    for (final timer in _progressTimers.values) {
      timer.cancel();
    }
    
    // Clean up all temp directories
    for (final tempDir in _tempDirs.values) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (e) {
        // Ignore errors when deleting temp directories
      }
    }
    
    // Clear all maps
    _activeProcesses.clear();
    _progressTimers.clear();
    _tempDirs.clear();
    _ffmpegOutputLogs.clear();
  }

  String _generateJobId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000000)}';
  }
}
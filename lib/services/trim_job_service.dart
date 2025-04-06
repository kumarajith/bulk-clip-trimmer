import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../models/trim_job.dart';
import 'ffmpeg_service.dart';
import 'logging_service.dart';
import 'app_directory_service.dart';

/// Service class for managing trim jobs
class TrimJobService {
  /// Singleton instance
  static final TrimJobService _instance = TrimJobService._internal();

  /// Factory constructor
  factory TrimJobService() => _instance;

  /// FFmpeg service
  final _ffmpegService = FFmpegService();

  /// Logging service
  final _loggingService = LoggingService();

  /// App directory service
  final _appDirectoryService = AppDirectoryService();

  /// Stream controller for trim jobs
  final _trimJobsController = StreamController<List<TrimJob>>.broadcast();

  /// List of trim jobs
  final List<TrimJob> _trimJobs = [];

  /// Map of job streams
  final Map<String, StreamSubscription<double>> _jobStreams = {};

  /// Storage file name
  static const String _storageFileName = 'trim_jobs.json';

  /// Internal constructor
  TrimJobService._internal();

  /// Get the trim jobs stream
  Stream<List<TrimJob>> get trimJobsStream => _trimJobsController.stream;

  /// Add a trim job
  Future<void> addTrimJob(TrimJob job) async {
    await _loggingService.info('Adding trim job', details: 'Path: ${job.filePath}');
    
    // Generate a unique ID for the job
    final jobWithId = job.copyWith(
      id: _generateJobId(),
    );
    
    _trimJobs.add(jobWithId);
    _trimJobsController.add(List.unmodifiable(_trimJobs));
    
    // Start processing the job
    _processJob(jobWithId);
  }

  /// Generate a unique job ID
  String _generateJobId() {
    return 'job_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  /// Process a job
  Future<void> _processJob(TrimJob job) async {
    try {
      await _loggingService.info('Processing trim job', details: 'ID: ${job.id}, Path: ${job.filePath}');
      
      // Get the progress stream from FFmpegService
      final progressStream = _ffmpegService.processTrimJob(job);
      
      // Listen to progress updates
      _jobStreams[job.id ?? ''] = progressStream.listen(
        (progress) {
          // Update job progress
          final index = _trimJobs.indexWhere((j) => j.id == job.id);
          if (index != -1) {
            _trimJobs[index] = _trimJobs[index].copyWith(progress: progress);
            _trimJobsController.add(List.unmodifiable(_trimJobs));
          }
        },
        onError: (error) {
          // Handle error
          final index = _trimJobs.indexWhere((j) => j.id == job.id);
          if (index != -1) {
            _trimJobs[index] = _trimJobs[index].copyWith(
              error: error.toString(),
              progress: 0.0,
            );
            _trimJobsController.add(List.unmodifiable(_trimJobs));
          }
          _loggingService.error('Error processing trim job', details: 'ID: ${job.id}, Error: $error');
        },
        onDone: () {
          // Clean up when done
          _jobStreams.remove(job.id);
        },
      );
    } catch (e) {
      await _loggingService.error('Error starting trim job', details: e.toString());
      
      // Update job with error
      final index = _trimJobs.indexWhere((j) => j.id == job.id);
      if (index != -1) {
        _trimJobs[index] = _trimJobs[index].copyWith(
          error: e.toString(),
          progress: 0.0,
        );
        _trimJobsController.add(List.unmodifiable(_trimJobs));
      }
    }
  }

  /// Process all jobs in the queue
  Future<void> processJobs() async {
    await _loggingService.info('Processing all jobs in queue');
    
    // Process each job in the queue
    for (final job in _trimJobs) {
      if (job.progress == 0.0 && job.error == null) {
        _processJob(job);
      }
    }
  }

  /// Cancel a trim job
  Future<void> cancelTrimJob(String jobId) async {
    await _loggingService.info('Cancelling trim job', details: 'ID: $jobId');
    
    // Cancel the FFmpeg process
    _ffmpegService.cancelProcess(jobId);
    
    // Cancel the stream subscription
    _jobStreams[jobId]?.cancel();
    _jobStreams.remove(jobId);
    
    // Remove the job from the list
    _trimJobs.removeWhere((job) => job.id == jobId);
    _trimJobsController.add(List.unmodifiable(_trimJobs));
  }

  /// Clear all trim jobs
  Future<void> clearTrimJobs() async {
    await _loggingService.info('Clearing all trim jobs');
    
    // Cancel all FFmpeg processes
    for (final jobId in _jobStreams.keys) {
      _ffmpegService.cancelProcess(jobId);
    }
    
    // Cancel all stream subscriptions
    for (final subscription in _jobStreams.values) {
      subscription.cancel();
    }
    _jobStreams.clear();
    
    // Clear the jobs list
    _trimJobs.clear();
    _trimJobsController.add(List.unmodifiable(_trimJobs));
  }

  /// Delete the storage file
  Future<void> deleteStorageFile() async {
    try {
      final directory = await _appDirectoryService.getAppDataDirectory();
      final file = File('${directory.path}/$_storageFileName');
      
      if (await file.exists()) {
        await file.delete();
        await _loggingService.info('Deleted trim jobs storage file');
      }
    } catch (e) {
      await _loggingService.error('Error deleting trim jobs storage file', details: e.toString());
    }
  }

  /// Dispose resources
  void dispose() {
    // Cancel all stream subscriptions
    for (final subscription in _jobStreams.values) {
      subscription.cancel();
    }
    _jobStreams.clear();
    
    // Close the controller
    _trimJobsController.close();
  }
}

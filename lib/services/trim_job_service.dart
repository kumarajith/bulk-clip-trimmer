import 'dart:async';
import 'dart:io';

import '../models/trim_job.dart';
import 'app_directory_service.dart';
import 'ffmpeg_service.dart';
import 'logging_service.dart';

/// Service for managing trim jobs
class TrimJobService {
  /// Storage file name
  static const String _storageFileName = 'trim_jobs.json';

  /// Singleton instance
  static final TrimJobService _instance = TrimJobService._internal();

  /// Factory constructor
  factory TrimJobService() => _instance;

  /// App directory service
  final _appDirectoryService = AppDirectoryService();

  /// Logging service
  final _loggingService = LoggingService();

  /// Internal constructor
  TrimJobService._internal();

  /// List of trim jobs
  final List<TrimJob> _trimJobs = [];

  /// Stream controller for trim jobs
  final _trimJobsController = StreamController<List<TrimJob>>.broadcast();

  /// FFmpeg service for video processing
  final _ffmpegService = FFmpegService();

  /// Stream of trim jobs
  Stream<List<TrimJob>> get trimJobsStream => _trimJobsController.stream;

  /// Get the list of trim jobs
  List<TrimJob> get trimJobs => List.unmodifiable(_trimJobs);

  /// Process a list of trim jobs
  Future<void> processJobs(List<TrimJob> jobs) async {
    await _loggingService.info('Processing ${jobs.length} trim jobs');
    
    for (final job in jobs) {
      if (!_trimJobs.contains(job)) {
        _trimJobs.add(job);
      }
    }
    
    _trimJobsController.add(_trimJobs);
    
    // Process each job
    for (final job in jobs) {
      if (job.progress < 1.0 && job.error == null) {
        await _processJob(job);
      }
    }
  }

  /// Process a single trim job
  Future<void> _processJob(TrimJob job) async {
    try {
      await _loggingService.info('Starting to process job', details: 'File: ${job.filePath}');
      
      // Use FFmpeg service to process the job
      final progressStream = _ffmpegService.processTrimJob(job);
      
      // Listen to progress updates
      await for (final progress in progressStream) {
        // Update job progress
        final updatedJob = job.copyWith(progress: progress);
        
        // Update job in list
        final index = _trimJobs.indexOf(job);
        if (index != -1) {
          _trimJobs[index] = updatedJob;
        }
        _updateAndBroadcastJobs();
      }
      
      // Job completed successfully
      await _loggingService.info('Job processed successfully', details: 'File: ${job.filePath}');
      
      // Log the trim job details
      await _loggingService.logTrimJob(
        filePath: job.filePath,
        startTime: job.startTime,
        endTime: job.endTime,
        outputFileName: job.outputFileName,
        outputFolders: job.outputFolders,
        audioOnly: job.audioOnly,
      );
      
    } catch (e) {
      // Update job with error
      final updatedJob = job.copyWith(error: e.toString());
      
      // Update job in list
      final index = _trimJobs.indexOf(job);
      if (index != -1) {
        _trimJobs[index] = updatedJob;
      }
      _updateAndBroadcastJobs();
      
      // Log the error
      await _loggingService.error('Error processing job', details: e.toString());
      
      // Log the trim job failure
      await _loggingService.logTrimJob(
        filePath: job.filePath,
        startTime: job.startTime,
        endTime: job.endTime,
        outputFileName: job.outputFileName,
        outputFolders: job.outputFolders,
        audioOnly: job.audioOnly,
        error: e.toString(),
      );
    }
  }

  /// Cancel a trim job
  Future<void> cancelJob(TrimJob job) async {
    final index = _trimJobs.indexOf(job);
    if (index != -1) {
      _trimJobs.removeAt(index);
      _trimJobsController.add(_trimJobs);
      await _loggingService.info('Job cancelled', details: 'File: ${job.filePath}');
    }
  }

  /// Clear all completed jobs
  Future<void> clearCompletedJobs() async {
    final completedCount = _trimJobs.where((job) => job.progress >= 1.0 || job.error != null).length;
    _trimJobs.removeWhere((job) => job.progress >= 1.0 || job.error != null);
    _trimJobsController.add(_trimJobs);
    await _loggingService.info('Cleared completed jobs', details: 'Removed $completedCount jobs');
  }

  /// Clear all jobs
  Future<void> clearAllJobs() async {
    final jobCount = _trimJobs.length;
    _trimJobs.clear();
    _trimJobsController.add(_trimJobs);
    await _loggingService.info('Cleared all jobs', details: 'Removed $jobCount jobs');
  }

  /// Load trim jobs from storage
  /// 
  /// Note: This method is kept for compatibility but now returns an empty list
  /// as we no longer persist trim jobs across sessions
  Future<List<TrimJob>> loadTrimJobs() async {
    await _loggingService.info('Trim jobs are no longer persisted across sessions');
    return [];
  }

  /// Save trim jobs to storage
  /// 
  /// Note: This method is kept for compatibility but does nothing
  /// as we no longer persist trim jobs across sessions
  Future<void> saveTrimJobs() async {
    // No-op - we don't save trim jobs anymore
    await _loggingService.debug('Trim jobs are no longer saved to storage');
  }

  /// Delete the trim jobs storage file if it exists
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
    _trimJobsController.close();
  }

  /// Helper method to update the stream controller with the current job list
  void _updateAndBroadcastJobs() {
    _loggingService.debug('TrimJobService: Broadcasting updated job list', 
      details: 'Jobs: ${_trimJobs.map((j) => '${j.outputFileName}: ${(j.progress * 100).toStringAsFixed(1)}% (Error: ${j.error != null})').join(', ')}');
    _trimJobsController.add(List.unmodifiable(_trimJobs));
  }
}

import 'dart:async';
import 'dart:io';

import '../models/trim_job.dart';
import '../providers/app_state_provider.dart';
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

  /// FFmpeg service for video processing
  final _ffmpegService = FFmpegService();

  /// App state provider
  AppStateProvider? _appStateProvider;

  /// Internal constructor
  TrimJobService._internal() {
    // Delete any existing storage file on startup to ensure jobs don't persist
    deleteStorageFile();
  }

  /// Set the app state provider
  void setAppStateProvider(AppStateProvider provider) {
    _appStateProvider = provider;
  }

  /// List of trim jobs
  final List<TrimJob> _trimJobs = [];

  /// Stream controller for trim jobs
  final _trimJobsController = StreamController<List<TrimJob>>.broadcast();

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
      
      // Update job status to processing
      final processingJob = job.copyWith(progress: 0.01);
      _updateJobInList(job, processingJob);
      
      // Create a stream to receive progress updates
      final progressController = StreamController<double>();
      
      // Listen to progress updates
      final subscription = progressController.stream.listen((progress) {
        // Update job with new progress
        final updatedJob = processingJob.copyWith(progress: progress);
        _updateJobInList(processingJob, updatedJob);
        
        // Log progress at key milestones
        if (progress == 0.01 || progress == 0.25 || progress == 0.5 || progress == 0.75 || progress >= 0.95) {
          _loggingService.debug('Job progress update', 
              details: 'File: ${job.filePath}, Progress: ${(progress * 100).toInt()}%');
        }
      }, onError: (error) {
        // Handle error
        final errorJob = processingJob.copyWith(error: error.toString(), progress: -1.0);
        _updateJobInList(processingJob, errorJob);
        _loggingService.error('Error in job progress stream', details: error.toString());
      });
      
      // Process the job with FFmpeg
      await _ffmpegService.processTrimJob(job, progressController);
      
      // Clean up subscription
      await subscription.cancel();
      
      // Update job status to completed
      final completedJob = processingJob.copyWith(progress: 1.0);
      _updateJobInList(processingJob, completedJob);
      
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
      final updatedJob = job.copyWith(error: e.toString(), progress: -1.0);
      
      // Update job in list
      _updateJobInList(job, updatedJob);
      
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
  
  /// Helper method to update a job in the list and notify listeners
  void _updateJobInList(TrimJob oldJob, TrimJob newJob) {
    final index = _trimJobs.indexOf(oldJob);
    if (index != -1) {
      _trimJobs[index] = newJob;
      _trimJobsController.add(List.unmodifiable(_trimJobs));
      
      // Also update the job in the app state provider if available
      _appStateProvider?.updateTrimJob(oldJob, newJob);
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
}

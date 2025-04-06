import 'dart:async';
import 'dart:convert';
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
    
    // Save jobs to storage
    await saveTrimJobs();
    
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
          _trimJobsController.add(_trimJobs);
          await saveTrimJobs();
        }
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
        _trimJobsController.add(_trimJobs);
        await saveTrimJobs();
      }
      
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
      await saveTrimJobs();
      await _loggingService.info('Job cancelled', details: 'File: ${job.filePath}');
    }
  }

  /// Clear all completed jobs
  Future<void> clearCompletedJobs() async {
    final completedCount = _trimJobs.where((job) => job.progress >= 1.0 || job.error != null).length;
    _trimJobs.removeWhere((job) => job.progress >= 1.0 || job.error != null);
    _trimJobsController.add(_trimJobs);
    await saveTrimJobs();
    await _loggingService.info('Cleared completed jobs', details: 'Removed $completedCount jobs');
  }

  /// Clear all jobs
  Future<void> clearAllJobs() async {
    final jobCount = _trimJobs.length;
    _trimJobs.clear();
    _trimJobsController.add(_trimJobs);
    await saveTrimJobs();
    await _loggingService.info('Cleared all jobs', details: 'Removed $jobCount jobs');
  }

  /// Load trim jobs from storage
  Future<List<TrimJob>> loadTrimJobs() async {
    try {
      final directory = await _appDirectoryService.getAppDataDirectory();
      final file = File('${directory.path}/$_storageFileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        
        _trimJobs.clear();
        _trimJobs.addAll(
          jsonList.map((json) => TrimJob.fromMap(json as Map<String, dynamic>)).toList(),
        );
        
        _trimJobsController.add(_trimJobs);
        await _loggingService.info('Loaded trim jobs from storage', details: '${_trimJobs.length} jobs loaded');
        return _trimJobs;
      }
    } catch (e) {
      await _loggingService.error('Error loading trim jobs', details: e.toString());
    }
    
    return [];
  }

  /// Save trim jobs to storage
  Future<void> saveTrimJobs() async {
    try {
      final directory = await _appDirectoryService.getAppDataDirectory();
      final file = File('${directory.path}/$_storageFileName');

      final jsonList = _trimJobs.map((job) => job.toMap()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
      await _loggingService.info('Trim jobs saved to storage', details: '${_trimJobs.length} jobs saved');
    } catch (e) {
      await _loggingService.error('Error saving trim jobs', details: e.toString());
    }
  }

  /// Dispose resources
  void dispose() {
    _trimJobsController.close();
  }
}

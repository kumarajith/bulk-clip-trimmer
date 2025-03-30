import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/trim_job.dart';
import 'ffmpeg_service.dart';

/// Service for managing trim jobs
class TrimJobService {
  /// Storage file name
  static const String _storageFileName = 'trim_jobs.json';

  /// Singleton instance
  static final TrimJobService _instance = TrimJobService._internal();

  /// Factory constructor
  factory TrimJobService() => _instance;

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
      // Simulate job processing
      final totalSteps = 10;
      for (var i = 1; i <= totalSteps; i++) {
        // Update job progress
        final progress = i / totalSteps;
        final updatedJob = job.copyWith(progress: progress);
        
        // Update job in list
        final index = _trimJobs.indexOf(job);
        if (index != -1) {
          _trimJobs[index] = updatedJob;
          _trimJobsController.add(_trimJobs);
          await saveTrimJobs();
        }
        
        // Simulate processing time
        await Future.delayed(const Duration(milliseconds: 500));
      }
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
      
      debugPrint('Error processing job: $e');
    }
  }

  /// Cancel a trim job
  Future<void> cancelJob(TrimJob job) async {
    final index = _trimJobs.indexOf(job);
    if (index != -1) {
      _trimJobs.removeAt(index);
      _trimJobsController.add(_trimJobs);
      await saveTrimJobs();
    }
  }

  /// Clear all completed jobs
  Future<void> clearCompletedJobs() async {
    _trimJobs.removeWhere((job) => job.progress >= 1.0 || job.error != null);
    _trimJobsController.add(_trimJobs);
    await saveTrimJobs();
  }

  /// Clear all jobs
  Future<void> clearAllJobs() async {
    _trimJobs.clear();
    _trimJobsController.add(_trimJobs);
    await saveTrimJobs();
  }

  /// Load trim jobs from storage
  Future<List<TrimJob>> loadTrimJobs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_storageFileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        
        _trimJobs.clear();
        _trimJobs.addAll(
          jsonList.map((json) => TrimJob.fromMap(json as Map<String, dynamic>)).toList(),
        );
        
        _trimJobsController.add(_trimJobs);
        return _trimJobs;
      }
    } catch (e) {
      debugPrint('Error loading trim jobs: $e');
    }
    
    return [];
  }

  /// Save trim jobs to storage
  Future<void> saveTrimJobs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_storageFileName');

      final jsonList = _trimJobs.map((job) => job.toMap()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving trim jobs: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _trimJobsController.close();
  }
}

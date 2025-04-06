import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../models/video_file.dart';
import '../models/trim_job.dart';
import '../models/label_folder.dart';
import '../services/video_service.dart';
import '../services/trim_job_service.dart';
import '../services/label_folder_service.dart';
import '../services/logging_service.dart';
import '../services/ffmpeg_service.dart';

/// Provider for managing application state
class AppStateProvider extends ChangeNotifier {
  /// Media player
  final Player player;

  /// Video service
  final _videoService = VideoService();

  /// Trim job service
  final _trimJobService = TrimJobService();

  /// Label folder service
  final _labelFolderService = LabelFolderService();
  
  /// Logging service
  final _loggingService = LoggingService();

  /// FFmpeg service
  final _ffmpegService = FFmpegService();

  /// List of videos in the playlist
  final List<VideoFile> _videos = [];

  /// List of trim jobs
  List<TrimJob> _trimJobs = [];

  /// Current video being played
  VideoFile? _currentVideo;

  /// Current trim range
  RangeValues? _trimRange;

  /// Output file name
  String _outputFileName = '';

  /// Flag for dark mode
  bool _isDarkMode = false;
  
  /// Flag for showing jobs panel
  bool _showJobsPanel = true;
  
  /// Width of the playlist panel
  double _playlistPanelWidth = 300;
  
  /// Subscription to trim jobs stream
  StreamSubscription<List<TrimJob>>? _trimJobsSubscription;
  
  /// Listener for label folders changes
  VoidCallback? _labelFoldersListener;

  /// Constructor
  AppStateProvider({required this.player}) {
    _loadInitialData();
    
    // Subscribe to trim jobs stream
    _trimJobsSubscription = _trimJobService.trimJobsStream.listen(_onTrimJobsChanged);
    
    // Subscribe to label folders changes
    _labelFoldersListener = () {
      _onLabelFoldersChanged();
    };
    _labelFolderService.labelFoldersNotifier.addListener(_labelFoldersListener!);
  }
  
  /// Handle label folders changes
  void _onLabelFoldersChanged() {
    notifyListeners();
  }
  
  /// Handle trim jobs changes
  void _onTrimJobsChanged(List<TrimJob> jobs) {
    _trimJobs = jobs;
    notifyListeners();
  }
  
  /// Load initial data
  Future<void> _loadInitialData() async {
    // Load label folders
    await _labelFolderService.loadLabelFolders();
    
    // Process any existing jobs
    _trimJobService.processJobs();
  }
  
  /// Get videos
  List<VideoFile> get videos => List.unmodifiable(_videos);
  
  /// Get current video
  VideoFile? get currentVideo => _currentVideo;
  
  /// Get trim range
  RangeValues? get trimRange => _trimRange;
  
  /// Get output file name
  String get outputFileName => _outputFileName;
  
  /// Get dark mode flag
  bool get isDarkMode => _isDarkMode;
  
  /// Get show jobs panel flag
  bool get showJobsPanel => _showJobsPanel;
  
  /// Get playlist panel width
  double get playlistPanelWidth => _playlistPanelWidth;
  
  /// Get trim jobs
  List<TrimJob> get trimJobs => _trimJobs;
  
  /// Get label folders
  List<LabelFolder> get labelFolders => _labelFolderService.labelFolders;
  
  /// Check if there are any active jobs in progress
  bool get hasActiveJobs {
    // Check if there are any jobs with progress > 0 and < 1
    return _trimJobs.any((job) => job.progress > 0 && job.progress < 1.0);
  }
  
  /// Set playlist panel width
  void setPlaylistPanelWidth(double width) {
    _playlistPanelWidth = width;
    notifyListeners();
  }

  /// Play a video
  Future<void> playVideo(VideoFile video) async {
    _currentVideo = video;
    
    // Reset trim range to null when changing videos
    _trimRange = null;
    
    // Play the video
    await player.open(Media(video.filePath));
    
    _loggingService.info('Playing video', details: 'Path: ${video.filePath}');
    notifyListeners();
  }
  
  /// Toggle play/pause
  void togglePlayPause() {
    if (player.state.playing) {
      player.pause();
      _loggingService.info('Video paused');
    } else {
      player.play();
      _loggingService.info('Video playing');
    }
    notifyListeners();
  }
  
  /// Set the trim range
  void setTrimRange(RangeValues range) {
    _trimRange = range;
    _loggingService.info('Trim range set', 
        details: 'Start: ${range.start}s, End: ${range.end}s');
    notifyListeners();
  }
  
  /// Set the output file name
  void setOutputFileName(String name) {
    _outputFileName = name;
    _loggingService.info('Output file name set', details: name);
    notifyListeners();
  }

  /// Toggle dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _loggingService.info('Dark mode toggled', details: 'Enabled: $_isDarkMode');
    notifyListeners();
  }

  /// Toggle jobs panel
  void toggleJobsPanel() {
    _showJobsPanel = !_showJobsPanel;
    _loggingService.info('Jobs panel toggled', details: 'Visible: $_showJobsPanel');
    notifyListeners();
  }

  /// Pick a video file
  Future<void> pickVideoFile() async {
    final video = await _videoService.pickVideoFile();
    if (video != null && !_videos.contains(video)) {
      _videos.add(video);
      _loggingService.info('Video added to playlist', details: 'Path: ${video.filePath}');
      notifyListeners();
    }
  }

  /// Pick a folder with videos
  Future<void> pickVideoFolder() async {
    final videos = await _videoService.pickDirectoryAndScanVideos();
    if (videos.isNotEmpty) {
      int addedCount = 0;
      for (final video in videos) {
        if (!_videos.contains(video)) {
          _videos.add(video);
          addedCount++;
        }
      }
      _loggingService.info('Videos added from folder', details: 'Added $addedCount of ${videos.length} videos');
      notifyListeners();
    }
  }

  /// Remove a video from the playlist
  void removeVideoFromPlaylist(VideoFile video) {
    _videos.remove(video);
    if (_currentVideo == video) {
      player.stop();
      _currentVideo = null;
      _trimRange = null;
    }
    _loggingService.info('Video removed from playlist', details: 'Path: ${video.filePath}');
    notifyListeners();
  }

  /// Clear the playlist
  void clearPlaylist() {
    _videos.clear();
    player.stop();
    _currentVideo = null;
    _trimRange = null;
    _loggingService.info('Playlist cleared');
    notifyListeners();
  }

  /// Add a label folder
  void addLabelFolder(LabelFolder labelFolder) {
    _labelFolderService.addLabelFolder(labelFolder);
    _loggingService.info('Label folder added', details: 'Label: ${labelFolder.label}, Path: ${labelFolder.folderPath}');
    // Notification will happen via the listener
  }

  /// Remove a label folder
  void removeLabelFolder(String label) {
    _labelFolderService.removeLabelFolder(label);
    _loggingService.info('Label folder removed', details: 'Label: $label');
    // Notification will happen via the listener
  }

  /// Toggle label selection
  void toggleLabelSelection(String label) {
    _labelFolderService.toggleLabelFolderSelection(label);
    _loggingService.info('Label folder selection toggled', details: 'Label: $label');
    // Notification will happen via the listener
  }

  /// Toggle audio only for a label folder
  void toggleAudioOnly(String label) {
    final folder = _labelFolderService.labelFolders.firstWhere(
      (lf) => lf.label == label,
      orElse: () => LabelFolder(label: '', folderPath: ''),
    );
    
    if (folder.label.isNotEmpty) {
      final updatedFolder = folder.copyWith(audioOnly: !folder.audioOnly);
      _labelFolderService.updateLabelFolder(updatedFolder);
      _loggingService.info('Label folder audio only toggled', 
        details: 'Label: $label, Audio Only: ${updatedFolder.audioOnly}');
      // Notification will happen via the listener
    }
  }

  /// Add a trim job
  Future<void> addTrimJob() async {
    if (_currentVideo == null || _trimRange == null) {
      _loggingService.error('Cannot add trim job', details: 'No video or trim range selected');
      return;
    }

    try {
      // Get selected folders
      final selectedFolders = _labelFolderService.labelFolders
          .where((folder) => folder.isSelected)
          .toList();

      if (selectedFolders.isEmpty) {
        _loggingService.error('Cannot add trim job', details: 'No output folders selected');
        return;
      }

      if (selectedFolders.isNotEmpty) {
        // Validate trim range against video duration
        final videoDuration = await _ffmpegService.getVideoDuration(_currentVideo!.filePath);
        if (videoDuration == null) {
          _loggingService.error('Could not determine video duration', 
              details: 'File: ${_currentVideo!.filePath}');
          return;
        }
        
        final videoDurationSeconds = videoDuration.inMilliseconds / 1000.0;
        
        // Log the current values for debugging
        _loggingService.info('Trim range values', 
            details: 'Range: ${_trimRange!.start} to ${_trimRange!.end}, ' +
                    'Video duration: ${videoDurationSeconds}s');
        
        // Validate start time
        if (_trimRange!.start >= videoDurationSeconds) {
          _loggingService.error('Start time exceeds video duration', 
              details: 'Start: ${_trimRange!.start}s, Video duration: ${videoDurationSeconds}s');
          return;
        }
        
        // Validate end time
        double endTime = _trimRange!.end;
        if (endTime > videoDurationSeconds) {
          _loggingService.warning('End time exceeds video duration, clamping to video end', 
              details: 'End: ${endTime}s, Video duration: ${videoDurationSeconds}s');
          endTime = videoDurationSeconds;
        }
        
        // Ensure minimum duration (at least 0.5 seconds)
        if (endTime - _trimRange!.start < 0.5) {
          _loggingService.error('Trim duration too short', 
              details: 'Duration must be at least 0.5 seconds');
          return;
        }

        // Create a job for each selected folder
        final jobs = <TrimJob>[];
        
        for (final folder in selectedFolders) {
          // The trim range values are already in seconds now
          final startTimeSeconds = _trimRange!.start;
          final endTimeSeconds = endTime;
          
          _loggingService.info('Creating trim job', 
              details: 'Using time values in seconds: ' +
                      'Start: ${startTimeSeconds}s, ' +
                      'End: ${endTimeSeconds}s');
          
          final job = TrimJob(
            filePath: _currentVideo!.filePath,
            startTime: startTimeSeconds,
            endTime: endTimeSeconds, // Use validated end time in seconds
            audioOnly: folder.audioOnly, // Use the folder's audioOnly setting
            outputFolders: [folder.folderPath], // One folder per job
            outputFileName: _outputFileName,
            progress: 0.0,
          );
          
          jobs.add(job);
        }
        
        _loggingService.info('Trim jobs added', 
          details: 'Created ${jobs.length} jobs for file: ${_currentVideo!.filePath}');
        
        // Add jobs to the service and let it process them
        for (final job in jobs) {
          _trimJobService.addTrimJob(job);
        }
        
        // Reset form
        _outputFileName = '';
        
        notifyListeners();
      } else {
        _loggingService.error('Cannot add trim job', details: 'No output folders selected');
      }
    } catch (e) {
      _loggingService.error('Error adding trim job', details: e.toString());
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    // Cancel subscriptions
    _trimJobsSubscription?.cancel();
    if (_labelFoldersListener != null) {
      _labelFolderService.labelFoldersNotifier.removeListener(_labelFoldersListener!);
    }
    
    super.dispose();
  }
}

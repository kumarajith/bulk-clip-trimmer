import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../models/video_file.dart';
import '../models/trim_job.dart';
import '../models/label_folder.dart';
import '../services/video_service.dart';
import '../services/trim_job_service.dart';
import '../services/label_folder_service.dart';

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

  /// List of videos in the playlist
  final List<VideoFile> _videos = [];

  /// List of trim jobs
  final List<TrimJob> _trimJobs = [];

  /// Current video being played
  VideoFile? _currentVideo;

  /// Current trim range
  RangeValues? _trimRange;

  /// Output file name
  String _outputFileName = '';

  /// Flag for dark mode
  bool _isDarkMode = false;

  /// Flag for showing jobs panel
  bool _showJobsPanel = false;
  
  /// Width of the playlist panel
  double _playlistPanelWidth = 300.0;

  /// Constructor
  AppStateProvider({required this.player}) {
    // Load initial data
    _loadInitialData();

    // Listen to player position changes
    player.streams.position.listen((position) {
      notifyListeners();
    });
    
    // Listen to label folder changes
    _labelFolderService.labelFoldersNotifier.addListener(_onLabelFoldersChanged);
  }
  
  /// Handle label folders changes
  void _onLabelFoldersChanged() {
    // Just notify listeners when label folders change
    notifyListeners();
  }

  /// Load initial data
  Future<void> _loadInitialData() async {
    try {
      // Load label folders
      await _labelFolderService.loadLabelFolders();
      
      // Load trim jobs
      final jobs = await _trimJobService.loadTrimJobs();
      _trimJobs.addAll(jobs);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  /// Get the list of videos (sorted by date descending)
  List<VideoFile> get videos {
    // Create a copy of the list to avoid modifying the original
    final sortedVideos = List<VideoFile>.from(_videos);
    
    // Sort by date descending (newest first)
    sortedVideos.sort((a, b) {
      if (a.dateModified == null && b.dateModified == null) return 0;
      if (a.dateModified == null) return 1; // null dates go to the end
      if (b.dateModified == null) return -1;
      return b.dateModified!.compareTo(a.dateModified!); // descending order
    });
    
    return sortedVideos;
  }

  /// Get the list of trim jobs
  List<TrimJob> get trimJobs => List.unmodifiable(_trimJobs);

  /// Get the list of label folders
  List<LabelFolder> get labelFolders => _labelFolderService.labelFolders;

  /// Get the current video
  VideoFile? get currentVideo => _currentVideo;

  /// Get the current trim range
  RangeValues? get trimRange => _trimRange;

  /// Get the output file name
  String get outputFileName => _outputFileName;

  /// Get whether dark mode is enabled
  bool get isDarkMode => _isDarkMode;

  /// Get whether jobs panel is shown
  bool get showJobsPanel => _showJobsPanel;

  /// Get playlist panel width
  double get playlistPanelWidth => _playlistPanelWidth;
  
  /// Set playlist panel width
  void setPlaylistPanelWidth(double width) {
    // Ensure width is within reasonable bounds (200-500px)
    _playlistPanelWidth = width.clamp(200.0, 500.0);
    notifyListeners();
  }

  /// Play a video
  void playVideo(VideoFile video) {
    _currentVideo = video;
    player.open(Media(video.filePath));
    notifyListeners();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
    notifyListeners();
  }

  /// Set the trim range
  void setTrimRange(RangeValues range) {
    _trimRange = range;
    notifyListeners();
  }

  /// Set the output file name
  void setOutputFileName(String name) {
    _outputFileName = name;
    notifyListeners();
  }

  /// Toggle dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Toggle jobs panel
  void toggleJobsPanel() {
    _showJobsPanel = !_showJobsPanel;
    notifyListeners();
  }

  /// Pick a video file
  Future<void> pickVideoFile() async {
    final video = await _videoService.pickVideoFile();
    if (video != null && !_videos.contains(video)) {
      _videos.add(video);
      notifyListeners();
    }
  }

  /// Pick a folder with videos
  Future<void> pickVideoFolder() async {
    final videos = await _videoService.pickDirectoryAndScanVideos();
    if (videos.isNotEmpty) {
      for (final video in videos) {
        if (!_videos.contains(video)) {
          _videos.add(video);
        }
      }
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
    notifyListeners();
  }

  /// Clear the playlist
  void clearPlaylist() {
    _videos.clear();
    player.stop();
    _currentVideo = null;
    _trimRange = null;
    notifyListeners();
  }

  /// Add a label folder
  void addLabelFolder(LabelFolder labelFolder) {
    _labelFolderService.addLabelFolder(labelFolder);
    // Notification will happen via the listener
  }

  /// Remove a label folder
  void removeLabelFolder(String label) {
    _labelFolderService.removeLabelFolder(label);
    // Notification will happen via the listener
  }

  /// Toggle label selection
  void toggleLabelSelection(String label) {
    _labelFolderService.toggleLabelFolderSelection(label);
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
      // Notification will happen via the listener
    }
  }

  /// Add a trim job
  void addTrimJob() {
    if (_currentVideo != null && _trimRange != null && _outputFileName.isNotEmpty) {
      final selectedFolders = _labelFolderService.getSelectedLabelFolders();
      
      if (selectedFolders.isNotEmpty) {
        // Create a job for each selected folder
        final jobs = <TrimJob>[];
        
        for (final folder in selectedFolders) {
          final job = TrimJob(
            filePath: _currentVideo!.filePath,
            startTime: _trimRange!.start,
            endTime: _trimRange!.end,
            audioOnly: folder.audioOnly, // Use the folder's audioOnly setting
            outputFolders: [folder.folderPath], // One folder per job
            outputFileName: _outputFileName,
            progress: 0.0,
          );
          
          jobs.add(job);
          _trimJobs.add(job);
        }
        
        // Start processing jobs
        _trimJobService.processJobs(jobs);
        
        // Reset form
        _outputFileName = '';
        
        notifyListeners();
      }
    }
  }

  /// Update a trim job
  void updateTrimJob(TrimJob job) {
    final index = _trimJobs.indexWhere((j) => j == job);
    if (index != -1) {
      _trimJobs[index] = job;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    _labelFolderService.labelFoldersNotifier.removeListener(_onLabelFoldersChanged);
    super.dispose();
  }
}

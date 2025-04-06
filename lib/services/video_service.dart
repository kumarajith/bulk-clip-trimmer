import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/video_file.dart';
import 'logging_service.dart';

/// Service class for handling video file operations
class VideoService {
  /// Singleton instance
  static final VideoService _instance = VideoService._internal();

  /// Factory constructor
  factory VideoService() => _instance;

  /// Logging service
  final _loggingService = LoggingService();

  /// Internal constructor
  VideoService._internal();

  /// Pick a single video file
  /// 
  /// Returns the selected video file or null if cancelled
  Future<VideoFile?> pickVideoFile() async {
    try {
      await _loggingService.info('Picking video file');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final fileObj = File(file.path!);
          final dateModified = await fileObj.lastModified();
          final videoFile = VideoFile(filePath: file.path!, dateModified: dateModified);
          
          await _loggingService.info('Video file picked', details: 'Path: ${file.path}');
          return videoFile;
        }
      } else {
        await _loggingService.info('Video file picking cancelled');
      }
      return null;
    } catch (e) {
      await _loggingService.error('Error picking video file', details: e.toString());
      rethrow;
    }
  }

  /// Pick a directory and scan for video files
  /// 
  /// Returns a list of video files found in the directory
  Future<List<VideoFile>> pickDirectoryAndScanVideos() async {
    try {
      await _loggingService.info('Picking directory for video scanning');
      
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result != null) {
        await _loggingService.info('Directory picked for scanning', details: 'Path: $result');
        return scanDirectoryForVideos(result);
      } else {
        await _loggingService.info('Directory picking cancelled');
      }
      return [];
    } catch (e) {
      await _loggingService.error('Error picking directory', details: e.toString());
      rethrow;
    }
  }

  /// Scan a directory for video files
  /// 
  /// Returns a list of video files found in the directory
  Future<List<VideoFile>> scanDirectoryForVideos(String directoryPath) async {
    try {
      await _loggingService.info('Scanning directory for videos', details: 'Path: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await _loggingService.warning('Directory does not exist', details: 'Path: $directoryPath');
        return [];
      }

      final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv'];
      
      final List<VideoFile> videos = [];
      
      await for (final entity in directory.list()) {
        if (entity is File) {
          final path = entity.path;
          final extension = path.substring(path.lastIndexOf('.')).toLowerCase();
          
          if (videoExtensions.contains(extension)) {
            final dateModified = await entity.lastModified();
            videos.add(VideoFile(filePath: path, dateModified: dateModified));
          }
        }
      }
      
      await _loggingService.info('Directory scan completed', details: 'Found ${videos.length} video files');
      return videos;
    } catch (e) {
      await _loggingService.error('Error scanning directory for videos', details: e.toString());
      rethrow;
    }
  }

  /// Pick a directory for output
  /// 
  /// Returns the selected directory path or null if cancelled
  Future<String?> pickOutputDirectory() async {
    try {
      await _loggingService.info('Picking output directory');
      
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result != null) {
        await _loggingService.info('Output directory picked', details: 'Path: $result');
      } else {
        await _loggingService.info('Output directory picking cancelled');
      }
      
      return result;
    } catch (e) {
      await _loggingService.error('Error picking output directory', details: e.toString());
      rethrow;
    }
  }
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/video_file.dart';

/// Service class for handling video file operations
class VideoService {
  /// Singleton instance
  static final VideoService _instance = VideoService._internal();

  /// Factory constructor
  factory VideoService() => _instance;

  /// Internal constructor
  VideoService._internal();

  /// Pick a single video file
  /// 
  /// Returns the selected video file or null if cancelled
  Future<VideoFile?> pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          return VideoFile(filePath: file.path!);
        }
      }
      return null;
    } catch (e) {
      print('Error picking video file: $e');
      rethrow;
    }
  }

  /// Pick a directory and scan for video files
  /// 
  /// Returns a list of video files found in the directory
  Future<List<VideoFile>> pickDirectoryAndScanVideos() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result != null) {
        return scanDirectoryForVideos(result);
      }
      return [];
    } catch (e) {
      print('Error picking directory: $e');
      rethrow;
    }
  }

  /// Scan a directory for video files
  /// 
  /// Returns a list of video files found in the directory
  Future<List<VideoFile>> scanDirectoryForVideos(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return [];
      }

      final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv'];
      
      final List<VideoFile> videos = [];
      
      await for (final entity in directory.list()) {
        if (entity is File) {
          final path = entity.path;
          final extension = path.substring(path.lastIndexOf('.')).toLowerCase();
          
          if (videoExtensions.contains(extension)) {
            videos.add(VideoFile(filePath: path));
          }
        }
      }
      
      return videos;
    } catch (e) {
      print('Error scanning directory for videos: $e');
      rethrow;
    }
  }

  /// Pick a directory for output
  /// 
  /// Returns the selected directory path or null if cancelled
  Future<String?> pickOutputDirectory() async {
    try {
      return await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      print('Error picking output directory: $e');
      rethrow;
    }
  }
}

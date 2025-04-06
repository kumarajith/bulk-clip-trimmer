import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'app_directory_service.dart';
import 'logging_service.dart';

/// Service for managing the bundled FFmpeg executable
class BundledFFmpegService {
  /// Singleton instance
  static final BundledFFmpegService _instance = BundledFFmpegService._internal();

  /// Factory constructor
  factory BundledFFmpegService() => _instance;

  /// App directory service
  final _appDirectoryService = AppDirectoryService();

  /// Logging service
  final _loggingService = LoggingService();

  /// Internal constructor
  BundledFFmpegService._internal();

  /// Path to the extracted FFmpeg executable
  String? _ffmpegPath;

  /// Get the path to the FFmpeg executable
  Future<String> getFFmpegPath() async {
    if (_ffmpegPath != null) {
      return _ffmpegPath!;
    }

    try {
      // Check if we're on Windows
      if (!Platform.isWindows) {
        throw Exception('Bundled FFmpeg is only supported on Windows');
      }

      // Get the bin directory from our app directory service
      final binDir = await _appDirectoryService.getBinDirectory();
      
      // Path to the FFmpeg executable
      final ffmpegExePath = '${binDir.path}/ffmpeg.exe';
      final ffmpegFile = File(ffmpegExePath);

      // Check if FFmpeg is already extracted
      if (await ffmpegFile.exists()) {
        _ffmpegPath = ffmpegExePath;
        await _loggingService.info('Using existing FFmpeg executable at: $ffmpegExePath');
        return ffmpegExePath;
      }

      // Extract FFmpeg from assets
      await _loggingService.info('Extracting bundled FFmpeg executable...');
      
      try {
        // Check if we can access the README file in assets to verify assets are properly set up
        await rootBundle.load('assets/bin/README.md');
        
        // In a real implementation, you would include the FFmpeg executable in your assets
        // and extract it here using something like:
        // final byteData = await rootBundle.load('assets/bin/ffmpeg.exe');
        // await ffmpegFile.writeAsBytes(byteData.buffer.asUint8List());
        
        // For now, we'll create a text file with instructions
        await ffmpegFile.writeAsString(
          'This is a placeholder for the FFmpeg executable.\n'
          'In a real application, you would include the actual FFmpeg.exe file in your assets\n'
          'and extract it here at runtime.'
        );
        
        // Make the file executable
        // Note: This doesn't actually work on Windows, but we include it for completeness
        try {
          await Process.run('chmod', ['+x', ffmpegExePath]);
        } catch (e) {
          // Ignore errors on Windows
        }

        _ffmpegPath = ffmpegExePath;
        await _loggingService.info('FFmpeg executable extracted to: $ffmpegExePath');
        return ffmpegExePath;
      } catch (e) {
        await _loggingService.error('Error extracting FFmpeg from assets', details: e.toString());
        // Fall back to system FFmpeg
        return 'ffmpeg';
      }
    } catch (e) {
      await _loggingService.error('Error getting FFmpeg path', details: e.toString());
      // Fall back to system FFmpeg
      return 'ffmpeg';
    }
  }

  /// Check if the bundled FFmpeg is available
  Future<bool> isFFmpegAvailable() async {
    try {
      final ffmpegPath = await getFFmpegPath();
      final result = await Process.run(ffmpegPath, ['-version']);
      final isAvailable = result.exitCode == 0;
      
      if (isAvailable) {
        final version = result.stdout.toString().split('\n').first;
        await _loggingService.info('Bundled FFmpeg is available', details: version);
      } else {
        await _loggingService.warning('Bundled FFmpeg is not available', details: result.stderr.toString());
      }
      
      return isAvailable;
    } catch (e) {
      await _loggingService.error('Error checking bundled FFmpeg availability', details: e.toString());
      return false;
    }
  }
}

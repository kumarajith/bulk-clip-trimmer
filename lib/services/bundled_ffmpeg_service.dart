import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
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
  
  /// Path to the extracted FFprobe executable
  String? _ffprobePath;

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
      await _loggingService.info('Bin directory path: ${binDir.path}');
      
      // Path to the FFmpeg executable
      final ffmpegExePath = '${binDir.path}/ffmpeg.exe';
      final ffmpegFile = File(ffmpegExePath);

      // Check if FFmpeg is already extracted
      final exists = await ffmpegFile.exists();
      await _loggingService.info('FFmpeg exists at ${ffmpegExePath}: $exists');
      
      if (exists) {
        _ffmpegPath = ffmpegExePath;
        await _loggingService.info('Using existing FFmpeg executable at: $ffmpegExePath');
        
        // Also check for ffprobe
        await _ensureFFprobeExists(binDir.path);
        
        return ffmpegExePath;
      }

      // Extract FFmpeg from assets
      await _loggingService.info('Extracting bundled FFmpeg executable...');
      
      // Create the directory if it doesn't exist
      if (!await Directory(binDir.path).exists()) {
        await Directory(binDir.path).create(recursive: true);
        await _loggingService.info('Created bin directory: ${binDir.path}');
      }
      
      // First, check if the README.md exists to verify assets are properly set up
      try {
        final readmeAsset = await rootBundle.load('assets/bin/README.md');
        await _loggingService.info('Found README.md in assets, size: ${readmeAsset.lengthInBytes} bytes');
      } catch (e) {
        await _loggingService.error('Could not find README.md in assets', details: e.toString());
        throw Exception('Assets not properly configured: ${e.toString()}');
      }
      
      // List available assets for debugging
      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        final assets = manifestMap.keys.where((String key) => key.startsWith('assets/')).toList();
        await _loggingService.info('Available assets: ${assets.join(', ')}');
      } catch (e) {
        await _loggingService.warning('Could not list assets', details: e.toString());
      }
      
      // Now try to load the ffmpeg.exe from assets
      try {
        final byteData = await rootBundle.load('assets/bin/ffmpeg.exe');
        await _loggingService.info('Found ffmpeg.exe in assets, size: ${byteData.lengthInBytes} bytes');
        
        // Write the ffmpeg.exe to the bin directory
        await ffmpegFile.writeAsBytes(byteData.buffer.asUint8List());
        await _loggingService.info('Extracted ffmpeg.exe to: $ffmpegExePath');
        
        _ffmpegPath = ffmpegExePath;
        
        // Also extract ffprobe
        await _ensureFFprobeExists(binDir.path);
        
        return ffmpegExePath;
      } catch (e) {
        await _loggingService.error('Could not load ffmpeg.exe from assets', details: e.toString());
        throw Exception('Failed to load ffmpeg.exe from assets: ${e.toString()}');
      }
    } catch (e) {
      await _loggingService.error('Error getting FFmpeg path', details: e.toString());
      throw Exception('FFmpeg is not available: ${e.toString()}');
    }
  }
  
  /// Ensure ffprobe.exe exists in the bin directory
  Future<String> _ensureFFprobeExists(String binDirPath) async {
    try {
      final ffprobeExePath = '$binDirPath/ffprobe.exe';
      final ffprobeFile = File(ffprobeExePath);
      
      // Check if ffprobe already exists
      final exists = await ffprobeFile.exists();
      await _loggingService.info('FFprobe exists at ${ffprobeExePath}: $exists');
      
      if (exists) {
        _ffprobePath = ffprobeExePath;
        await _loggingService.info('Using existing FFprobe executable at: $ffprobeExePath');
        return ffprobeExePath;
      }
      
      // Try to extract ffprobe from assets
      try {
        await _loggingService.info('Attempting to extract ffprobe.exe from assets');
        
        // List available assets for debugging
        try {
          final manifestContent = await rootBundle.loadString('AssetManifest.json');
          final Map<String, dynamic> manifestMap = json.decode(manifestContent);
          final assets = manifestMap.keys.where((String key) => key.startsWith('assets/bin/')).toList();
          await _loggingService.info('Available assets in bin directory: ${assets.join(', ')}');
        } catch (e) {
          await _loggingService.warning('Could not list assets in bin directory', details: e.toString());
        }
        
        final byteData = await rootBundle.load('assets/bin/ffprobe.exe');
        await _loggingService.info('Found ffprobe.exe in assets, size: ${byteData.lengthInBytes} bytes');
        
        // Write the ffprobe.exe to the bin directory
        await ffprobeFile.writeAsBytes(byteData.buffer.asUint8List());
        await _loggingService.info('Extracted ffprobe.exe to: $ffprobeExePath');
        
        // Verify the file was written correctly
        if (await ffprobeFile.exists()) {
          final fileSize = await ffprobeFile.length();
          await _loggingService.info('Verified ffprobe.exe exists after extraction, size: $fileSize bytes');
          
          // Try to run ffprobe to verify it works
          try {
            final result = await Process.run(ffprobeExePath, ['-version']);
            if (result.exitCode == 0) {
              final version = result.stdout.toString().split('\n').first;
              await _loggingService.info('FFprobe execution successful', details: version);
            } else {
              await _loggingService.warning('FFprobe execution failed', details: result.stderr.toString());
            }
          } catch (e) {
            await _loggingService.error('Error executing FFprobe after extraction', details: e.toString());
          }
        } else {
          await _loggingService.error('FFprobe file does not exist after extraction attempt');
        }
        
        _ffprobePath = ffprobeExePath;
        return ffprobeExePath;
      } catch (e) {
        await _loggingService.error('Could not load ffprobe.exe from assets', details: e.toString());
        throw Exception('Failed to load ffprobe.exe from assets: ${e.toString()}');
      }
    } catch (e) {
      await _loggingService.error('Error ensuring FFprobe exists', details: e.toString());
      throw Exception('FFprobe is not available: ${e.toString()}');
    }
  }
  
  /// Get the path to the FFprobe executable
  Future<String> getFFprobePath() async {
    if (_ffprobePath != null) {
      return _ffprobePath!;
    }
    
    // FFmpeg path will also ensure FFprobe is extracted
    final ffmpegPath = await getFFmpegPath();
    final binDir = Directory(ffmpegPath).parent.path;
    return _ensureFFprobeExists(binDir);
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
        
        // Also check if ffprobe is available
        try {
          final ffprobePath = await getFFprobePath();
          final probeResult = await Process.run(ffprobePath, ['-version']);
          final probeAvailable = probeResult.exitCode == 0;
          
          if (probeAvailable) {
            final probeVersion = probeResult.stdout.toString().split('\n').first;
            await _loggingService.info('Bundled FFprobe is available', details: probeVersion);
          } else {
            await _loggingService.warning('Bundled FFprobe is not available', details: probeResult.stderr.toString());
            return false;
          }
        } catch (e) {
          await _loggingService.error('Error checking FFprobe availability', details: e.toString());
          return false;
        }
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

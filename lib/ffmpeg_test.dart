import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'services/app_directory_service.dart';
import 'services/logging_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const FFmpegTestApp());
}

class FFmpegTestApp extends StatefulWidget {
  const FFmpegTestApp({Key? key}) : super(key: key);

  @override
  _FFmpegTestAppState createState() => _FFmpegTestAppState();
}

class _FFmpegTestAppState extends State<FFmpegTestApp> {
  final _logs = <String>[];
  final _appDirectoryService = AppDirectoryService();
  final _loggingService = LoggingService();
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      _log('Starting FFmpeg extraction test...');
      await _loggingService.info('Starting FFmpeg extraction test');
      
      // Initialize app directory service
      await _appDirectoryService.initialize();
      _log('App directory service initialized');
      await _loggingService.info('App directory service initialized');
      
      // Get bin directory
      final binDir = await _appDirectoryService.getBinDirectory();
      _log('Bin directory: ${binDir.path}');
      await _loggingService.info('Bin directory', details: binDir.path);
      
      // Check if directory exists
      final binDirExists = await Directory(binDir.path).exists();
      _log('Bin directory exists: $binDirExists');
      await _loggingService.info('Bin directory exists', details: binDirExists.toString());
      
      if (!binDirExists) {
        await Directory(binDir.path).create(recursive: true);
        _log('Created bin directory');
        await _loggingService.info('Created bin directory');
      }
      
      // List available assets
      _log('Listing available assets:');
      await _loggingService.info('Listing available assets');
      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        final assets = manifestMap.keys.where((String key) => key.startsWith('assets/')).toList();
        
        if (assets.isEmpty) {
          _log('No assets found starting with "assets/"');
          await _loggingService.info('No assets found starting with "assets/"');
        } else {
          for (final asset in assets) {
            _log('- $asset');
            await _loggingService.info('Asset', details: asset);
          }
        }
      } catch (e) {
        _log('Error listing assets: $e');
        await _loggingService.error('Error listing assets', details: e.toString());
      }
      
      // Check for README.md
      _log('Checking for README.md in assets:');
      await _loggingService.info('Checking for README.md in assets');
      try {
        final readmeAsset = await rootBundle.load('assets/bin/README.md');
        _log('README.md found, size: ${readmeAsset.lengthInBytes} bytes');
        await _loggingService.info('README.md found', details: readmeAsset.lengthInBytes.toString());
        
        // Try to read content
        final readmeBytes = readmeAsset.buffer.asUint8List();
        final readmeContent = utf8.decode(readmeBytes);
        _log('README.md content (first 100 chars): ${readmeContent.substring(0, readmeContent.length > 100 ? 100 : readmeContent.length)}...');
        await _loggingService.info('README.md content', details: readmeContent.substring(0, readmeContent.length > 100 ? 100 : readmeContent.length));
      } catch (e) {
        _log('Error loading README.md: $e');
        await _loggingService.error('Error loading README.md', details: e.toString());
      }
      
      // Check for ffmpeg.exe
      _log('Checking for ffmpeg.exe in assets:');
      await _loggingService.info('Checking for ffmpeg.exe in assets');
      try {
        final ffmpegAsset = await rootBundle.load('assets/bin/ffmpeg.exe');
        _log('ffmpeg.exe found, size: ${ffmpegAsset.lengthInBytes} bytes');
        await _loggingService.info('ffmpeg.exe found', details: ffmpegAsset.lengthInBytes.toString());
        
        // Try to extract ffmpeg.exe
        final ffmpegExePath = '${binDir.path}/ffmpeg.exe';
        final ffmpegFile = File(ffmpegExePath);
        
        await ffmpegFile.writeAsBytes(ffmpegAsset.buffer.asUint8List());
        _log('Extracted ffmpeg.exe to: $ffmpegExePath');
        await _loggingService.info('Extracted ffmpeg.exe', details: ffmpegExePath);
        
        // Check if file exists and has correct size
        final extractedFile = File(ffmpegExePath);
        if (await extractedFile.exists()) {
          final fileSize = await extractedFile.length();
          _log('Extracted file exists, size: $fileSize bytes');
          await _loggingService.info('Extracted file exists', details: fileSize.toString());
          
          // Try to run ffmpeg
          _log('Testing ffmpeg execution:');
          await _loggingService.info('Testing ffmpeg execution');
          try {
            final result = await Process.run(ffmpegExePath, ['-version']);
            if (result.exitCode == 0) {
              final version = result.stdout.toString().split('\n').first;
              _log('FFmpeg execution successful: $version');
              await _loggingService.info('FFmpeg execution successful', details: version);
            } else {
              _log('FFmpeg execution failed: ${result.stderr}');
              await _loggingService.error('FFmpeg execution failed', details: result.stderr);
            }
          } catch (e) {
            _log('Error executing FFmpeg: $e');
            await _loggingService.error('Error executing FFmpeg', details: e.toString());
          }
        } else {
          _log('Extracted file does not exist');
          await _loggingService.error('Extracted file does not exist');
        }
      } catch (e) {
        _log('Error loading ffmpeg.exe: $e');
        await _loggingService.error('Error loading ffmpeg.exe', details: e.toString());
      }
      
      _log('FFmpeg extraction test completed');
      await _loggingService.info('FFmpeg extraction test completed');
    } catch (e) {
      _log('Error during test: $e');
      await _loggingService.error('Error during test', details: e.toString());
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _log(String message) {
    print(message);
    setState(() {
      _logs.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FFmpeg Extraction Test'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isRunning ? null : _runTests,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test Results:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(color: Colors.green, fontFamily: 'monospace'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

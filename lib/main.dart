import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

import 'providers/app_state_provider.dart';
import 'screens/main_screen.dart';
import 'services/app_directory_service.dart';
import 'services/trim_job_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MediaKit
  MediaKit.ensureInitialized();
  
  // Initialize app directories
  final appDirectoryService = AppDirectoryService();
  await appDirectoryService.initialize();
  
  // Delete any existing trim jobs file to ensure a clean slate on startup
  final trimJobService = TrimJobService();
  await trimJobService.deleteStorageFile();
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Media player
  late final Player _player;
  
  // Video controller
  late final VideoController _controller;
  
  // App state provider
  late final AppStateProvider _appState;
  
  // Global key for navigator
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Initialize player and controller
    _player = Player();
    _controller = VideoController(_player);
    
    // Initialize app state provider
    _appState = AppStateProvider(player: _player);
    
    // Set up window close handler
    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      // Check if there are any active jobs
      final hasActiveJobs = _appState.hasActiveJobs;
      
      if (hasActiveJobs) {
        // Show a warning dialog
        final shouldClose = await showDialog<bool>(
          context: _navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Warning'),
            content: const Text(
              'You have active trim jobs in progress. Closing the app will cancel these jobs. '
              'Are you sure you want to exit?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit Anyway'),
              ),
            ],
          ),
        ) ?? false;
        
        return shouldClose;
      }
      
      return true;
    });
  }

  @override
  void dispose() {
    // Dispose resources
    _player.dispose();
    _appState.dispose();
    FlutterWindowClose.setWindowShouldCloseHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Bulk Clip Trimmer',
          theme: _appState.isDarkMode ? ThemeData.dark() : ThemeData.light(),
          debugShowCheckedModeBanner: false,
          home: MainScreen(
            appState: _appState,
            controller: _controller,
          ),
        );
      },
    );
  }
}

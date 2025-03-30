import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'providers/app_state_provider.dart';
import 'screens/main_screen.dart';

void main() {
  // Initialize MediaKit
  MediaKit.ensureInitialized();
  
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

  @override
  void initState() {
    super.initState();
    
    // Initialize player and controller
    _player = Player();
    _controller = VideoController(_player);
    
    // Initialize app state provider
    _appState = AppStateProvider(player: _player);
  }

  @override
  void dispose() {
    // Dispose resources
    _player.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return MaterialApp(
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

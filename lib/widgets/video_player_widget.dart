import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../providers/app_state_provider.dart';
import 'video_trim_seekbar.dart';

/// Widget for video playback with controls
class VideoPlayerWidget extends StatefulWidget {
  /// Video controller
  final VideoController controller;

  /// Constructor
  const VideoPlayerWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  /// Stream for position and duration updates
  late Stream<Map<String, Duration>> _positionAndDurationStream;
  late AppStateProvider _appState;

  @override
  void initState() {
    super.initState();
    
    // We'll set up the stream in didChangeDependencies
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get the app state provider
    _appState = Provider.of<AppStateProvider>(context);
    
    // Combine position and duration streams
    _positionAndDurationStream = Rx.combineLatest2<Duration, Duration, Map<String, Duration>>(
      _appState.player.stream.position,
      _appState.player.stream.duration,
      (position, duration) => {'position': position, 'duration': duration},
    );
    
    // Set default volume to 40%
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState.player.setVolume(40.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle space key for play/pause
        if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
          _appState.togglePlayPause();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video display
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(
                    controller: widget.controller,
                    controls: (VideoState state) => const SizedBox.shrink(),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          // Playback controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Play/Pause button
                StreamBuilder<bool>(
                  stream: _appState.player.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _appState.togglePlayPause,
                    );
                  },
                ),
                
                // Seekbar - now takes 90% of available space
                Expanded(
                  flex: 9, // 90% of the space
                  child: StreamBuilder<Map<String, Duration>>(
                    stream: _positionAndDurationStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }

                      final position = snapshot.data!['position'] ?? Duration.zero;
                      final duration = snapshot.data!['duration'] ?? Duration.zero;
                      
                      return VideoTrimSeekBar(
                        duration: duration,
                        position: position,
                        onPositionChange: (newPosition) async {
                          await _appState.player.seek(newPosition);
                        },
                        onTrimChange: (newRange) {
                          _appState.setTrimRange(newRange);
                        },
                      );
                    },
                  ),
                ),
                
                // Volume control - now takes 10% of available space
                Expanded(
                  flex: 1, // 10% of the space
                  child: StreamBuilder<double>(
                    stream: _appState.player.stream.volume,
                    builder: (context, snapshot) {
                      final volume = snapshot.data ?? 40.0; // Default to 40%
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, size: 18),
                          Expanded(
                            child: Slider(
                              value: volume,
                              min: 0.0,
                              max: 100.0,
                              divisions: 20,
                              onChanged: (value) {
                                _appState.player.setVolume(value);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

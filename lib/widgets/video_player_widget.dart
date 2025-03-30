import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:rxdart/rxdart.dart';

import '../providers/app_state_provider.dart';
import 'video_trim_seekbar.dart';

/// Widget for video playback with controls
class VideoPlayerWidget extends StatefulWidget {
  /// App state provider
  final AppStateProvider appState;
  
  /// Video controller
  final VideoController controller;

  /// Constructor
  const VideoPlayerWidget({
    Key? key,
    required this.appState,
    required this.controller,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  /// Stream for position and duration updates
  late Stream<Map<String, Duration>> _positionAndDurationStream;

  @override
  void initState() {
    super.initState();
    
    // Combine position and duration streams
    _positionAndDurationStream = Rx.combineLatest2<Duration, Duration, Map<String, Duration>>(
      widget.appState.player.stream.position,
      widget.appState.player.stream.duration,
      (position, duration) => {'position': position, 'duration': duration},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle space key for play/pause
        if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
          widget.appState.togglePlayPause();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video display
          Expanded(
            child: Video(
              controller: widget.controller,
              controls: (VideoState state) => SizedBox.shrink(),
            ),
          ),
          
          // Playback controls
          Row(
            children: [
              // Play/Pause button
              StreamBuilder<bool>(
                stream: widget.appState.player.stream.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: widget.appState.togglePlayPause,
                  );
                },
              ),
              
              // Seekbar
              Expanded(
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
                        await widget.appState.player.seek(newPosition);
                      },
                      onTrimChange: (newRange) {
                        widget.appState.setTrimRange(newRange);
                      },
                    );
                  },
                ),
              ),
              
              // Volume control
              StreamBuilder<double>(
                stream: widget.appState.player.stream.volume,
                builder: (context, snapshot) {
                  final volume = snapshot.data ?? 0.0;
                  return Row(
                    children: [
                      Icon(Icons.volume_up),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: Slider(
                          value: volume,
                          min: 0.0,
                          max: 100.0,
                          onChanged: (value) async {
                            await widget.appState.player.setVolume(value);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

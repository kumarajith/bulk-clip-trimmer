import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../providers/app_state_provider.dart';
import 'video_trim_seekbar.dart';

/// Widget for video playback with controls
class VideoPlayerWidget extends StatelessWidget {
  /// Video controller
  final VideoController controller;

  /// Constructor
  const VideoPlayerWidget({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get appState from provider
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle space key for play/pause
        if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
          appState.togglePlayPause();
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
                    controller: controller,
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
                Consumer<AppStateProvider>(
                  builder: (context, appStateConsumer, _) {
                    return StreamBuilder<bool>(
                      stream: appStateConsumer.player.stream.playing,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: appStateConsumer.togglePlayPause,
                          tooltip: isPlaying ? 'Pause' : 'Play',
                        );
                      },
                    );
                  },
                ),
                
                // Seekbar - now takes 90% of available space
                Expanded(
                  flex: 9, // 90% of the space
                  child: Consumer<AppStateProvider>(
                    builder: (context, appStateConsumer, _) {
                      return StreamBuilder<Map<String, Duration>>(
                        stream: Rx.combineLatest2<Duration, Duration, Map<String, Duration>>(
                          appStateConsumer.player.stream.position,
                          appStateConsumer.player.stream.duration,
                          (position, duration) => {'position': position, 'duration': duration},
                        ),
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
                              // Seek the player when seekbar position changes
                              await appStateConsumer.player.seek(newPosition);
                            },
                            onTrimChange: (newRange) {
                              appStateConsumer.setTrimRange(newRange);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Volume control - now takes 10% of available space
                Expanded(
                  flex: 1, // 10% of the space
                  child: Consumer<AppStateProvider>(
                    builder: (context, appStateConsumer, _) {
                      return StreamBuilder<double>(
                        stream: appStateConsumer.player.stream.volume,
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
                                    appStateConsumer.player.setVolume(value);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
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

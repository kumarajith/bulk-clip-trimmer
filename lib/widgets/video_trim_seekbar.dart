import 'dart:async';
import 'package:flutter/material.dart';

/// Widget for video trimming with a custom seekbar
class VideoTrimSeekBar extends StatefulWidget {
  /// Total video duration
  final Duration duration;
  
  /// Current position
  final Duration position;
  
  /// Callback for position changes
  final ValueChanged<Duration> onPositionChange;
  
  /// Callback for trim range changes
  final ValueChanged<RangeValues> onTrimChange;

  /// Constructor
  const VideoTrimSeekBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.onPositionChange,
    required this.onTrimChange,
  }) : super(key: key);

  @override
  _VideoTrimSeekBarState createState() => _VideoTrimSeekBarState();
}

class _VideoTrimSeekBarState extends State<VideoTrimSeekBar> {
  /// Left trim handle position in milliseconds
  late double _handleLeft;
  
  /// Right trim handle position in milliseconds
  late double _handleRight;
  
  /// Current position in milliseconds
  late double _position;
  
  /// Timer for debouncing position changes
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeValues(true);
  }

  @override
  void didUpdateWidget(VideoTrimSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeValues(oldWidget.duration != widget.duration);
    // Always update position when widget updates
    _position = widget.position.inMilliseconds.toDouble();
  }

  /// Initialize the seekbar values
  void _initializeValues(bool updateHandlebars) {
    final duration = widget.duration.inMilliseconds > 0 ? 
        widget.duration.inMilliseconds.toDouble() : 1.0;
    
    if (updateHandlebars) {
      _handleLeft = 0.2 * duration; // 20% of total duration
      _handleRight = 0.8 * duration; // 80% of total duration
      // Notify parent about initial trim range
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
      });
    }
    _position = widget.position.inMilliseconds.toDouble();
  }

  /// Debounce position changes to avoid too many updates
  void _onPositionChangeDebounced(Duration newDuration) {
    _debounceTimer?.cancel(); // Cancel any active timer
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onPositionChange(newDuration);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // Dispose of the timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final duration = widget.duration.inMilliseconds > 0 ? 
        widget.duration.inMilliseconds.toDouble() : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.9; // Add some margin for cleaner look
        final margin = constraints.maxWidth * 0.05;

        return SizedBox(
          height: 60, // Increased overall height to accommodate taller hitbox
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Highlighted trim area
              Positioned(
                top: 20, // Adjusted position to center in the taller container
                left: margin + (_handleLeft / duration) * width,
                width: ((_handleRight - _handleLeft) / duration) * width,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.yellow[700] : Colors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Seek bar background and hitbox
              Positioned(
                top: 10, // Adjusted position to center in the taller container
                left: margin,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newPosition = (_position + (details.delta.dx / width) * duration)
                          .clamp(0.0, duration);
                      _position = newPosition;

                      final newDuration = Duration(milliseconds: _position.round());
                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  onTapDown: (details) {
                    setState(() {
                      final tapPosition = (details.localPosition.dx / width) * duration;
                      _position = tapPosition.clamp(0.0, duration);

                      final newDuration = Duration(milliseconds: _position.round());
                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  child: Container(
                    height: 40, // Significantly increased hitbox height
                    width: width,
                    color: Colors.transparent, // Transparent container for larger hitbox
                    child: Center(
                      child: Container(
                        height: 5, // Actual visual bar remains 5px
                        width: width,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.black,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Left trim handle
              Positioned(
                top: 15,
                left: margin + (_handleLeft / duration) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleLeft = ((_handleLeft + (details.delta.dx / width) * duration)
                          .clamp(0.0, _handleRight - 1000)); // Ensure minimum 1 second gap
                      widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
                    });
                  },
                  child: Container(
                    height: 30,
                    width: 20,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.green[700] : Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_left, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),

              // Right trim handle
              Positioned(
                top: 15,
                left: margin + (_handleRight / duration) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleRight = ((_handleRight + (details.delta.dx / width) * duration)
                          .clamp(_handleLeft + 1000, duration)); // Ensure minimum 1 second gap
                      widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
                    });
                  },
                  child: Container(
                    height: 30,
                    width: 20,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.green[700] : Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_right, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),

              // Position indicator
              Positioned(
                top: 22.5,
                left: margin + (_position / duration) * width - 7.5,
                child: Container(
                  height: 15,
                  width: 15,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),

              // Time indicators
              Positioned(
                bottom: 0,
                left: margin,
                child: Text(
                  _formatDuration(Duration(milliseconds: _position.round())),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: margin,
                child: Text(
                  _formatDuration(widget.duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

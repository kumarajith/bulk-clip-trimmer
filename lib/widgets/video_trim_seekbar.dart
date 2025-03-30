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
  }

  /// Initialize the seekbar values
  void _initializeValues(bool updateHandlebars) {
    if (updateHandlebars) {
      _handleLeft = 0.2 * widget.duration.inMilliseconds; // 20% of total duration
      _handleRight = 0.8 * widget.duration.inMilliseconds; // 80% of total duration
      widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.9; // Add some margin for cleaner look
        final margin = constraints.maxWidth * 0.05;

        return SizedBox(
          height: 50, // Reduced height for better visuals
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Highlighted trim area
              Positioned(
                top: 15,
                left: margin + (_handleLeft / widget.duration.inMilliseconds) * width,
                right: margin + ((widget.duration.inMilliseconds - _handleRight) / widget.duration.inMilliseconds) * width,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.yellow[700] : Colors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Seek bar background
              Positioned(
                top: 22.5,
                left: margin,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newPosition = (_position + (details.delta.dx / width) * widget.duration.inMilliseconds)
                          .clamp(0.0, widget.duration.inMilliseconds.toDouble());
                      _position = newPosition;

                      final newDuration = Duration(milliseconds: _position.round());
                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  onTapDown: (details) {
                    setState(() {
                      final tapPosition = (details.localPosition.dx / width) * widget.duration.inMilliseconds;
                      _position = tapPosition.clamp(0.0, widget.duration.inMilliseconds.toDouble());

                      final newDuration = Duration(milliseconds: _position.round());
                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  child: Container(
                    height: 5,
                    width: width,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.black,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),

              // Left trim handle
              Positioned(
                top: 10,
                left: margin + (_handleLeft / widget.duration.inMilliseconds) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleLeft = ((_handleLeft + (details.delta.dx / width) * widget.duration.inMilliseconds)
                          .clamp(0.0, _handleRight));
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
                  ),
                ),
              ),

              // Right trim handle
              Positioned(
                top: 10,
                left: margin + (_handleRight / widget.duration.inMilliseconds) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleRight = ((_handleRight + (details.delta.dx / width) * widget.duration.inMilliseconds)
                          .clamp(_handleLeft, widget.duration.inMilliseconds.toDouble()));
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
                  ),
                ),
              ),

              // Position indicator
              Positioned(
                top: 17.5,
                left: margin + (_position / widget.duration.inMilliseconds) * width - 7.5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newPosition = (_position + (details.delta.dx / width) * widget.duration.inMilliseconds)
                          .clamp(0.0, widget.duration.inMilliseconds.toDouble());
                      _position = newPosition;

                      final newDuration = Duration(milliseconds: _position.round());
                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  child: Container(
                    height: 15,
                    width: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? Colors.grey[300] : Colors.black,
                    ),
                  ),
                ),
              ),
              
              // Time indicators
              Positioned(
                bottom: 0,
                left: margin,
                child: Text(
                  _formatDuration(Duration(milliseconds: _position.round())),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Positioned(
                bottom: 0,
                right: margin,
                child: Text(
                  _formatDuration(widget.duration),
                  style: TextStyle(fontSize: 12),
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
    return "$minutes:$seconds";
  }
}

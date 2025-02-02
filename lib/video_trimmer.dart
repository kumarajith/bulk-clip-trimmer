import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';

class VideoTrimSeekBarWidget extends StatefulWidget {
  final Duration duration; // Total video duration
  final Duration position; // Current position
  final ValueChanged<Duration> onPositionChange; // Seek bar callback
  final ValueChanged<RangeValues> onTrimChange; // Trim range callback

  const VideoTrimSeekBarWidget({
    Key? key,
    required this.duration,
    required this.position,
    required this.onPositionChange,
    required this.onTrimChange,
  }) : super(key: key);

  @override
  _VideoTrimSeekBarWidgetState createState() => _VideoTrimSeekBarWidgetState();
}

class _VideoTrimSeekBarWidgetState extends State<VideoTrimSeekBarWidget> {
  late double _handleLeft; // Left green handle position in seconds
  late double _handleRight; // Right green handle position in seconds
  late double _position; // Black seek bar position in seconds
  Timer? _debounceTimer; // Timer for debouncing `onPositionChange`
  bool isinitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeValues(true);
  }

  @override
  void didUpdateWidget(VideoTrimSeekBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeValues(oldWidget.duration != widget.duration);
  }

  void _initializeValues(updateHandlebars) {
    if (updateHandlebars) {
      _handleLeft = 0.2 * widget.duration.inSeconds; // 20% of total duration
      _handleRight = 0.8 * widget.duration.inSeconds; // 80% of total duration
    }
    _position = widget.position.inSeconds.toDouble();
  }

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
              // Yellow highlighted area
              Positioned(
                top: 15,
                left: margin + (_handleLeft / widget.duration.inSeconds) * width,
                right: margin + ((widget.duration.inSeconds - _handleRight) / widget.duration.inSeconds) * width,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.yellow[700] : Colors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Seek bar background (black bar with rounded edges)
              Positioned(
                top: 22.5, // Adjusted to vertically center the seek bar
                left: margin,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newPosition = (_position + (details.delta.dx / width) * widget.duration.inSeconds)
                          .clamp(0.0, widget.duration.inSeconds.toDouble());
                      _position = newPosition;

                      final newDuration = Duration(seconds: _position.round());

                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  onTapDown: (details) {
                    setState(() {
                      final tapPosition = (details.localPosition.dx / width) * widget.duration.inSeconds;
                      _position = tapPosition.clamp(0.0, widget.duration.inSeconds.toDouble());

                      final newDuration = Duration(seconds: _position.round());

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

              // Left handle (green)
              Positioned(
                top: 10, // Adjusted to vertically center the handle
                left: margin + (_handleLeft / widget.duration.inSeconds) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleLeft = ((_handleLeft + (details.delta.dx / width) * widget.duration.inSeconds)
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

              // Right handle (green)
              Positioned(
                top: 10, // Adjusted to vertically center the handle
                left: margin + (_handleRight / widget.duration.inSeconds) * width - 10,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleRight = ((_handleRight + (details.delta.dx / width) * widget.duration.inSeconds)
                          .clamp(_handleLeft, widget.duration.inSeconds.toDouble()));
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

              // Position indicator (black circle)
              Positioned(
                top: 17.5, // Adjusted to vertically center the circle
                left: margin + (_position / widget.duration.inSeconds) * width - 7.5,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newPosition = (_position + (details.delta.dx / width) * widget.duration.inSeconds)
                          .clamp(0.0, widget.duration.inSeconds.toDouble());
                      _position = newPosition;

                      final newDuration = Duration(seconds: _position.round());

                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  onTapDown: (details) {
                    setState(() {
                      final tapPosition = (details.localPosition.dx / width) * widget.duration.inSeconds;
                      _position = tapPosition.clamp(0.0, widget.duration.inSeconds.toDouble());

                      final newDuration = Duration(seconds: _position.round());

                      _onPositionChangeDebounced(newDuration);
                    });
                  },
                  child: Container(
                    height: 15,
                    width: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? Colors.grey[800] : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

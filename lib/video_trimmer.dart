import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';

class VideoTrimSeekBar extends StatefulWidget {
  final Duration duration; // Total video duration
  final Duration position; // Current position
  final ValueChanged<Duration> onPositionChange; // Seek bar callback
  final ValueChanged<RangeValues> onTrimChange; // Trim range callback

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
  late double _handleLeft; // Left green handle position in seconds
  late double _handleRight; // Right green handle position in seconds
  late double _position; // Black seek bar position in seconds
  Timer? _debounceTimer; // Timer for debouncing `onPositionChange`

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    _handleLeft = 0.2 * widget.duration.inSeconds; // Example initial left handle position (20%)
    _handleRight = 0.8 * widget.duration.inSeconds; // Example initial right handle position (80%)
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.9; // Add some margin for cleaner look
        final margin = constraints.maxWidth * 0.05;

        return SizedBox(
          height: 70, // Increased height for better visuals
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Yellow highlighted area
              Positioned(
                top: 20,
                left: margin + (_handleLeft / widget.duration.inSeconds) * width,
                right: margin + ((widget.duration.inSeconds - _handleRight) / widget.duration.inSeconds) * width,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              // Seek bar background (black bar with rounded edges)
              Positioned(
                top: 30,
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
                    height: 10,
                    width: width,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),

              // Left handle (green)
              Positioned(
                left: margin + (_handleLeft / widget.duration.inSeconds) * width - 15,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleLeft = ((_handleLeft + (details.delta.dx / width) * widget.duration.inSeconds)
                          .clamp(0.0, _handleRight));
                      widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
                    });
                  },
                  child: Container(
                    height: 40,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),

              // Right handle (green)
              Positioned(
                left: margin + (_handleRight / widget.duration.inSeconds) * width - 15,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _handleRight = ((_handleRight + (details.delta.dx / width) * widget.duration.inSeconds)
                          .clamp(_handleLeft, widget.duration.inSeconds.toDouble()));
                      widget.onTrimChange(RangeValues(_handleLeft, _handleRight));
                    });
                  },
                  child: Container(
                    height: 40,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),

              // Position indicator (black circle)
              Positioned(
                top: 20,
                left: margin + (_position / widget.duration.inSeconds) * width - 10,
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
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
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

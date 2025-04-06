import 'dart:async';
import 'package:flutter/material.dart';

/// Widget for video trimming with a custom seekbar
class VideoTrimSeekBar extends StatefulWidget {
  /// Total video duration
  final Duration duration;
  
  /// Current position - This widget is controlled by this value
  final Duration position;
  
  /// Callback for position changes
  final ValueChanged<Duration> onPositionChange;
  
  /// Callback for trim range changes
  final ValueChanged<RangeValues> onTrimChange;

  /// Constructor
  const VideoTrimSeekBar({
    Key? key,
    required this.duration,
    required this.position, // Relies on external position
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

  // Temporary state to hold seek position during user interaction
  double? _seekingPositionMs;

  @override
  void initState() {
    super.initState();
    _initializeValues(true);
  }

  /// Initialize the seekbar values (handles only)
  void _initializeValues(bool updateHandlebars) {
    final durationMs = widget.duration.inMilliseconds > 0 ? 
        widget.duration.inMilliseconds.toDouble() : 1.0;
    
    if (updateHandlebars) {
      // Initialize handles relative to duration
      _handleLeft = 0.0; // Start at the beginning
      _handleRight = durationMs; // End at the total duration

      // Notify parent about initial trim range (full range)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if mounted before calling callback
           widget.onTrimChange(RangeValues(_handleLeft / 1000, _handleRight / 1000));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final durationMs = widget.duration.inMilliseconds > 0 ? 
        widget.duration.inMilliseconds.toDouble() : 1.0;
    // Actual position from the player
    final actualPositionMs = widget.position.inMilliseconds.toDouble().clamp(0.0, durationMs);
    // Use seeking position if available, otherwise actual position
    final displayPositionMs = _seekingPositionMs ?? actualPositionMs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.9; // Usable width
        final margin = constraints.maxWidth * 0.05;

        return SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Highlighted trim area
              Positioned(
                top: 20,
                left: margin + (_handleLeft / durationMs) * width,
                width: ((_handleRight - _handleLeft) / durationMs) * width,
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
                top: 10,
                left: margin,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    // Calculate initial drag position
                    final dragPositionMs = (details.localPosition.dx / width) * durationMs;
                    final newPositionMs = dragPositionMs.clamp(0.0, durationMs);
                    setState(() {
                      _seekingPositionMs = newPositionMs;
                    });
                    widget.onPositionChange(Duration(milliseconds: newPositionMs.round()));
                  },
                  onHorizontalDragUpdate: (details) {
                    // Calculate new position during drag
                    // Note: Using _seekingPositionMs for smoother relative drag
                    final currentPos = _seekingPositionMs ?? actualPositionMs; 
                    final newPositionMs = (currentPos + (details.delta.dx / width) * durationMs)
                        .clamp(0.0, durationMs);
                    setState(() {
                      _seekingPositionMs = newPositionMs; // Update seeking position
                    });
                    // Call callback to trigger actual player seek
                    widget.onPositionChange(Duration(milliseconds: newPositionMs.round()));
                  },
                  onHorizontalDragEnd: (details) {
                    // Clear seeking position when drag ends
                    setState(() {
                      _seekingPositionMs = null;
                    });
                  },
                  onTapDown: (details) {
                    // Calculate new position directly based on tap
                    final tapPositionMs = (details.localPosition.dx / width) * durationMs;
                    final newPositionMs = tapPositionMs.clamp(0.0, durationMs);
                    setState(() {
                      _seekingPositionMs = newPositionMs; // Set seeking position on tap
                    });
                    // Call callback to trigger actual player seek
                    widget.onPositionChange(Duration(milliseconds: newPositionMs.round()));
                  },
                  onTapUp: (details) {
                    // Clear seeking position when tap ends
                    // (May be redundant with onTapDown calling seek immediately,
                    // but good for consistency)
                    setState(() {
                      _seekingPositionMs = null;
                    });
                  },
                  child: Container(
                    height: 40, 
                    width: width,
                    color: Colors.transparent,
                    child: Center(
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
                ),
              ),
              
              // Current position indicator (Thumb)
              Positioned(
                top: 15, 
                left: margin + (displayPositionMs / durationMs) * width - 5, // Use displayPositionMs
                child: Container(
                  width: 10,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red, // Make it visible
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Left trim handle
              Positioned(
                top: 15,
                left: margin + (_handleLeft / durationMs) * width - 10, // Adjust position based on handle width
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newHandleLeft = _handleLeft + (details.delta.dx / width) * durationMs;
                      // Prevent crossing the display position indicator if seeking
                      final minRightBound = _seekingPositionMs != null 
                        ? _seekingPositionMs! - 100 // Small buffer from seeking thumb
                        : _handleRight - 1000; // Default: Min 1 sec gap from right handle
                      _handleLeft = newHandleLeft.clamp(0.0, minRightBound);
                      
                      widget.onTrimChange(RangeValues(_handleLeft / 1000, _handleRight / 1000));
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
                left: margin + (_handleRight / durationMs) * width - 10, // Adjust position based on handle width
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newHandleRight = _handleRight + (details.delta.dx / width) * durationMs;
                      // Prevent crossing the display position indicator if seeking
                      final minLeftBound = _seekingPositionMs != null 
                        ? _seekingPositionMs! + 100 // Small buffer from seeking thumb
                        : _handleLeft + 1000; // Default: Min 1 sec gap from left handle
                      _handleRight = newHandleRight.clamp(minLeftBound, durationMs);

                      widget.onTrimChange(RangeValues(_handleLeft / 1000, _handleRight / 1000));
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
            ],
          ),
        );
      },
    );
  }
}

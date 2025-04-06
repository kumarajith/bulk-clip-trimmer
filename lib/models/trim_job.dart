/// Model class representing a video trimming job
class TrimJob {
  /// The full path to the source video file
  final String filePath;
  
  /// Start time in seconds for the trim
  final double startTime;
  
  /// End time in seconds for the trim
  final double endTime;
  
  /// Whether to extract audio only
  final bool audioOnly;
  
  /// List of output folders where the trimmed video should be saved
  final List<String> outputFolders;
  
  /// The output file name (without extension)
  final String outputFileName;
  
  /// Current progress of the trim job (0.0 to 1.0)
  final double progress;
  
  /// Path to the source video file (alias for filePath)
  String get sourceFilePath => filePath;
  
  /// Start time as a Duration
  /// Note: startTime is already in seconds, so we convert to milliseconds for the Duration
  Duration get startDuration => Duration(milliseconds: (startTime * 1000).toInt());
  
  /// End time as a Duration
  /// Note: endTime is already in seconds, so we convert to milliseconds for the Duration
  Duration get endDuration => Duration(milliseconds: (endTime * 1000).toInt());
  
  /// Error message if any
  final String? error;
  
  /// Constructor
  const TrimJob({
    required this.filePath,
    required this.startTime,
    required this.endTime,
    required this.audioOnly,
    required this.outputFolders,
    required this.outputFileName,
    this.progress = 0.0,
    this.error,
  });
  
  /// Create a copy with updated properties
  TrimJob copyWith({
    String? filePath,
    double? startTime,
    double? endTime,
    bool? audioOnly,
    List<String>? outputFolders,
    String? outputFileName,
    double? progress,
    String? error,
  }) {
    return TrimJob(
      filePath: filePath ?? this.filePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      audioOnly: audioOnly ?? this.audioOnly,
      outputFolders: outputFolders ?? this.outputFolders,
      outputFileName: outputFileName ?? this.outputFileName,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
  
  /// Create a TrimJob from a map
  factory TrimJob.fromMap(Map<String, dynamic> map) {
    return TrimJob(
      filePath: map['fileName'] as String,
      startTime: map['start'] as double,
      endTime: map['end'] as double,
      audioOnly: map['audioOnly'] as bool,
      outputFolders: List<String>.from(map['folders'] as List),
      outputFileName: map['outputFileName'] as String,
      progress: map['progress'] as double? ?? 0.0,
      error: map['error'],
    );
  }
  
  /// Convert TrimJob to a map
  Map<String, dynamic> toMap() {
    return {
      'fileName': filePath,
      'start': startTime,
      'end': endTime,
      'audioOnly': audioOnly,
      'folders': outputFolders,
      'outputFileName': outputFileName,
      'progress': progress,
      'error': error,
    };
  }
}

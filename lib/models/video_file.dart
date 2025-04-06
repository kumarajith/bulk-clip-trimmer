/// Model class for a video file
class VideoFile {
  /// Path to the video file
  final String filePath;
  
  /// Date when the file was last modified
  final DateTime? dateModified;

  /// Constructor
  const VideoFile({
    required this.filePath,
    this.dateModified,
  });

  /// Get the file name from the path
  String get fileName => filePath.split('/').last;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoFile &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;
}

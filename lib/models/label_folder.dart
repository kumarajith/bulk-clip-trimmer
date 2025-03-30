/// Model class representing a label and its associated output folder
class LabelFolder {
  /// The label name
  final String label;
  
  /// The associated folder path
  final String folderPath;
  
  /// Whether this label is selected for the current trim job
  final bool isSelected;
  
  /// Whether to extract audio only for this folder
  final bool audioOnly;
  
  /// Constructor
  const LabelFolder({
    required this.label,
    required this.folderPath,
    this.isSelected = false,
    this.audioOnly = false,
  });
  
  /// Create a copy of this LabelFolder with updated properties
  LabelFolder copyWith({
    String? label,
    String? folderPath,
    bool? isSelected,
    bool? audioOnly,
  }) {
    return LabelFolder(
      label: label ?? this.label,
      folderPath: folderPath ?? this.folderPath,
      isSelected: isSelected ?? this.isSelected,
      audioOnly: audioOnly ?? this.audioOnly,
    );
  }
  
  /// Convert to a map
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'folderPath': folderPath,
      'isSelected': isSelected,
      'audioOnly': audioOnly,
    };
  }

  /// Create from a map
  factory LabelFolder.fromMap(Map<String, dynamic> map) {
    return LabelFolder(
      label: map['label'] ?? '',
      folderPath: map['folderPath'] ?? '',
      isSelected: map['isSelected'] ?? false,
      audioOnly: map['audioOnly'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelFolder &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          folderPath == other.folderPath &&
          audioOnly == other.audioOnly;

  @override
  int get hashCode => label.hashCode ^ folderPath.hashCode ^ audioOnly.hashCode;
}

/// Enum representing the AR mode
enum ArMode {
  /// World AR mode - back camera, plane detection, anchors
  world,
  
  /// Face AR mode - front camera, face detection
  face,
}

/// Extension methods for ArMode
extension ArModeExtension on ArMode {
  /// Returns true if this is World AR mode
  bool get isWorld => this == ArMode.world;
  
  /// Returns true if this is Face AR mode
  bool get isFace => this == ArMode.face;
  
  /// Returns the string representation
  String get name => this == ArMode.world ? 'world' : 'face';
  
  /// Creates ArMode from string
  static ArMode fromString(String value) {
    switch (value.toLowerCase()) {
      case 'face':
        return ArMode.face;
      case 'world':
      default:
        return ArMode.world;
    }
  }
}
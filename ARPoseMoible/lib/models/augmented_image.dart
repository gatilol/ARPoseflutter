// Configuration for augmented image detection and 3D model display

/// Data class representing an augmented image configuration
class AugmentedImageConfig {
  /// Unique identifier for the image
  final String name;

  /// Asset path to the image used for detection
  final String imagePath;

  /// Asset path to the 3D model displayed when image is detected
  final String modelPath;

  /// Physical width of the printed image in meters
  final double physicalWidth;

  /// Scale factor for the 3D model
  final double modelScale;

  /// Vertical offset for the 3D model (negative = lower)
  final double modelYOffset;

  /// Additional rotation offset in degrees
  final double modelRotationOffset;

  const AugmentedImageConfig({
    required this.name,
    required this.imagePath,
    required this.modelPath,
    this.physicalWidth = 0.20,
    this.modelScale = 0.1,
    this.modelYOffset = 0.0,
    this.modelRotationOffset = 0.0,
  });

  /// Convert to map for passing to native code
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imagePath': imagePath,
      'modelPath': modelPath,
      'physicalWidth': physicalWidth,
      'modelScale': modelScale,
      'modelYOffset': modelYOffset,
      'modelRotationOffset': modelRotationOffset,
    };
  }
}


// ──────────────────────────────────────────────────────────────
// Augmented Images Configuration
// ──────────────────────────────────────────────────────────────

/// List of augmented images to detect
const List<AugmentedImageConfig> augmentedImages = [
  AugmentedImageConfig(
    name: 'poster_01',
    imagePath: 'assets/ar_images/poster_01/image.png',
    modelPath: 'assets/ar_images/poster_01/model.glb',
    physicalWidth: 0.20,
    modelScale: 0.1,
    modelYOffset: -0.05,
    modelRotationOffset: 0.0,
  ),
];
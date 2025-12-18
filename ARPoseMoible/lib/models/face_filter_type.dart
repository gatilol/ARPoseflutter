/// Types of face filters available in Face AR mode
enum FaceFilterType {
  /// No filter applied
  none,

  /// 3D model filter (GLB files - glasses, masks, etc.)
  model3D,

  /// Makeup texture filter (PNG files - freckles, face paint, etc.)
  makeup,
}
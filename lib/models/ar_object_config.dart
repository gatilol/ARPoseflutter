import 'package:flutter/material.dart';

/// Configuration d'un objet AR (modèle 3D GLB)
class ARObjectConfig {
  final String modelPath;       // Chemin du modèle GLB
  final double scale;            // Échelle du modèle
  final bool autoRotate;         // Rotation automatique
  
  const ARObjectConfig({
    required this.modelPath,
    this.scale = 1.0,
    this.autoRotate = true,
  });
  
  /// Configuration par défaut avec le modèle humain
  factory ARObjectConfig.defaultModel() {
    return const ARObjectConfig(
      modelPath: 'assets/models/human_body_base_cartoon.glb',
      scale: 0.5,
      autoRotate: true,
    );
  }
}
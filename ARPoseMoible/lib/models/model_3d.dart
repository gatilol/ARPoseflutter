import 'package:flutter/material.dart';

import 'face_filter_type.dart';

/// Represents a 3D model or filter that can be applied in AR
class Model3D {
  /// Display name of the model
  final String name;

  /// Asset path to the model file
  final String path;

  /// Icon to display in the UI
  final IconData icon;

  /// Optional description for the model
  final String? description;

  /// Type of filter (for Face AR categorization)
  final FaceFilterType filterType;

  // ========== SCALE TO UNITS (taille en mètres) ==========
  /// Taille cible du modèle en MÈTRES
  /// Le modèle sera normalisé pour que sa plus grande dimension
  /// fasse exactement cette taille.
  /// 
  /// Exemples:
  /// - scale: 0.15 → modèle de 15 cm (comme le reticle)
  /// - scale: 0.5  → modèle de 50 cm
  /// - scale: 1.0  → modèle de 1 mètre
  /// - scale: 2.0  → modèle de 2 mètres
  /// 
  /// Note: Non utilisé pour Face AR (ignoré)
  final double scale;
  // =======================================================

  const Model3D({
    required this.name,
    required this.path,
    required this.icon,
    this.description,
    this.filterType = FaceFilterType.model3D,
    this.scale = 1.0,
  });
}


// ──────────────────────────────────────────────────────────────
// World AR Models
// ──────────────────────────────────────────────────────────────

/// Available 3D models for World AR mode
const List<Model3D> worldModels = [
  Model3D(
    name: 'EVA-01',
    path: 'assets/models/world/eva_01_esg.glb',
    icon: Icons.android,
    description: 'Evangelion Unit-01',
    scale: 2.0, // 50 cm de haut
  ),
  Model3D(
    name: 'EVA-02',
    path: 'assets/models/world/evangelion_unit-02.glb',
    icon: Icons.android,
    description: 'Evangelion Unit-02',
    scale: 0.5, // 50 cm de haut
  ),
  Model3D(
    name: 'Human',
    path: 'assets/models/world/human_body_base_cartoon.glb',
    icon: Icons.accessibility_new,
    description: 'Cartoon human model',
    scale: 0.3, // 30 cm de haut
  ),
];


// ──────────────────────────────────────────────────────────────
// Face AR Filters
// ──────────────────────────────────────────────────────────────

/// Available filters for Face AR mode (3D models + makeup textures)
/// Note: scale is ignored for Face AR filters
const List<Model3D> faceFilters = [
  // 3D Accessories
  Model3D(
    name: 'Glasses',
    path: 'assets/models/face/3D/fox.glb',
    icon: Icons.visibility,
    description: 'Sunglasses',
    filterType: FaceFilterType.model3D,
  ),

  // Makeup Textures
  Model3D(
    name: 'Freckles',
    path: 'assets/models/face/makeup/freckles.png',
    icon: Icons.face_retouching_natural,
    description: 'Freckles',
    filterType: FaceFilterType.makeup,
  ),
  Model3D(
    name: 'Face Paint',
    path: 'assets/models/face/makeup/face.png',
    icon: Icons.brush,
    description: 'Face paint',
    filterType: FaceFilterType.makeup,
  ),
  Model3D(
    name: 'Canonical',
    path: 'assets/models/face/makeup/canonical_face.png',
    icon: Icons.grid_on,
    description: 'UV template (test)',
    filterType: FaceFilterType.makeup,
  ),
];
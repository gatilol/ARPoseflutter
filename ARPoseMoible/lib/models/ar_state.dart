import 'package:flutter/foundation.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';

import 'ar_mode.dart';

/// Manages the AR application state
/// Notifies listeners when state changes for UI updates
class ARState extends ChangeNotifier {
  /// List of placed AR nodes in the scene
  final List<ARNode> nodes = [];

  /// Whether at least one model has been placed
  bool hasPlacedModel = false;

  /// Whether a photo capture is in progress (hides UI overlays)
  bool isCapturing = false;

  /// Whether the reticle is currently visible
  bool reticleVisible = false;

  /// Current AR mode (world or face)
  ArMode currentMode = ArMode.world;

  /// Whether a face is currently detected (Face AR only)
  bool isFaceDetected = false;

  /// Last detected face pose data (Face AR only)
  Map<String, dynamic>? lastFacePose;


  // ──────────────────────────────────────────────────────────────
  // Node Management
  // ──────────────────────────────────────────────────────────────

  /// Add a node to the scene
  void addNode(ARNode node) {
    nodes.add(node);
    hasPlacedModel = nodes.isNotEmpty;
    notifyListeners();
  }

  /// Remove a specific node from the scene
  void removeNode(ARNode node) {
    nodes.remove(node);
    hasPlacedModel = nodes.isNotEmpty;
    notifyListeners();
  }

  /// Clear all nodes from the scene
  void clearNodes() {
    nodes.clear();
    hasPlacedModel = false;
    notifyListeners();
  }


  // ──────────────────────────────────────────────────────────────
  // UI State
  // ──────────────────────────────────────────────────────────────

  /// Set photo capture state
  void setCapturing(bool value) {
    isCapturing = value;
    notifyListeners();
  }

  /// Set reticle visibility state
  void setReticleVisible(bool value) {
    reticleVisible = value;
    notifyListeners();
  }


  // ──────────────────────────────────────────────────────────────
  // Face AR State
  // ──────────────────────────────────────────────────────────────

  /// Set the current AR mode
  void setMode(ArMode mode) {
    currentMode = mode;
    notifyListeners();
  }

  /// Set face detection state
  void setFaceDetected(bool detected) {
    isFaceDetected = detected;
    notifyListeners();
  }

  /// Update face pose data
  void updateFacePose(Map<String, dynamic> pose) {
    lastFacePose = pose;
    notifyListeners();
  }

  /// Convenience getter for World AR mode
  bool get isWorldMode => currentMode == ArMode.world;

  /// Convenience getter for Face AR mode
  bool get isFaceMode => currentMode == ArMode.face;
}
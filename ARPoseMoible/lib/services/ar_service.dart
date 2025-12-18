import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart' as ar_models;
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart' as ar_types;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/ar_state.dart';
import '../models/ar_mode.dart';

/// Main AR service that handles AR session, object placement, and mode switching
class ARService {
  late ARSessionManager sessionManager;
  late ARObjectManager objectManager;
  late ARAnchorManager anchorManager;

  final ARState state;
  String modelPath;
  final String reticlePath;

  // Reticle tracking
  ar_models.ARNode? _reticleNode;
  ARPlaneAnchor? _reticleAnchor;
  vector.Quaternion _currentReticleRotation = vector.Quaternion.identity();
  vector.Matrix4? _lastHitTransform;

  // Face AR state
  ArMode _currentMode = ArMode.world;
  String? _currentFaceModelPath;

  // Public getters
  ArMode get currentMode => _currentMode;
  bool get isWorldMode => _currentMode == ArMode.world;
  bool get isFaceMode => _currentMode == ArMode.face;
  String? get currentFaceModelPath => _currentFaceModelPath;

  ARService({
    required this.state,
    required this.modelPath,
    required this.reticlePath,
  });

  /// Update the current World AR model path
  void updateModelPath(String newModelPath) {
    modelPath = newModelPath;
  }

  /// Initialize AR managers when ARView is created
  void onARViewCreated(
    ARSessionManager session,
    ARObjectManager object,
    ARAnchorManager anchor,
  ) {
    sessionManager = session;
    objectManager = object;
    anchorManager = anchor;

    sessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: false,
      handleRotation: false,
    );

    sessionManager.onPlaneOrPointTap = (hits) => onPlaneOrPointTapped(hits);

    setupFaceARCallbacks();
  }


  // ──────────────────────────────────────────────────────────────
  // Plane Tap & Reticle
  // ──────────────────────────────────────────────────────────────

  /// Handle tap on detected plane - place reticle
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    final ARHitTestResult planeHit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    _lastHitTransform = planeHit.worldTransform;
    _currentReticleRotation = vector.Quaternion.identity();

    await _updateReticleWithRotation();
  }

  /// Update reticle position and rotation
  Future<void> _updateReticleWithRotation() async {
    if (_lastHitTransform == null) return;

    await _removeReticleSilent();

    var anchorTransformation = _lastHitTransform!;

    // Apply rotation using Matrix4
    final rotationMatrix = vector.Matrix4.identity();
    rotationMatrix.setRotation(_currentReticleRotation.asRotationMatrix());

    anchorTransformation = anchorTransformation * rotationMatrix;

    final anchor = ARPlaneAnchor(transformation: anchorTransformation);
    final anchorId = await anchorManager.addAnchor(anchor);

    if (anchorId == null) return;

    final reticleNode = ar_models.ARNode(
      type: ar_types.NodeType.localGLTF2,
      uri: reticlePath,
      scale: vector.Vector3(kReticleScale, kReticleScale, kReticleScale),
    );

    final nodeId = await objectManager.addNode(reticleNode, planeAnchor: anchor);

    if (nodeId != null) {
      _reticleNode = reticleNode;
      _reticleAnchor = anchor;
      state.setReticleVisible(true);
    } else {
      try {
        await anchorManager.removeAnchor(anchor);
      } catch (_) {}
    }
  }

  /// Rotate the reticle by the given angle in radians
  Future<void> rotateReticle(double angleRadians) async {
    if (_reticleNode == null || _lastHitTransform == null) return;

    // Create incremental rotation quaternion around Y axis
    final rotationAxis = vector.Vector3(0.0, 1.0, 0.0);
    final deltaRotation = vector.Quaternion.axisAngle(rotationAxis, angleRadians);

    // Multiply quaternions for cumulative rotation
    _currentReticleRotation = _currentReticleRotation * deltaRotation;
    _currentReticleRotation.normalize();

    await _updateReticleWithRotation();
  }

  /// Remove reticle without logging errors
  Future<void> _removeReticleSilent() async {
    if (_reticleNode != null) {
      try {
        await objectManager.removeNode(_reticleNode!);
      } catch (_) {}
      _reticleNode = null;
    }

    if (_reticleAnchor != null) {
      try {
        await anchorManager.removeAnchor(_reticleAnchor!);
      } catch (_) {}
      _reticleAnchor = null;
    }

    state.setReticleVisible(false);
  }


  // ──────────────────────────────────────────────────────────────
  // Model Placement
  // ──────────────────────────────────────────────────────────────

  /// Place the selected 3D model at the current reticle position
  Future<void> placeModelAtReticle() async {
    if (_reticleAnchor == null || _lastHitTransform == null) return;

    try {
      var modelTransformation = _lastHitTransform!;

      // Apply current rotation
      final rotationMatrix = vector.Matrix4.identity();
      rotationMatrix.setRotation(_currentReticleRotation.asRotationMatrix());
      modelTransformation = modelTransformation * rotationMatrix;

      final modelAnchor = ARPlaneAnchor(transformation: modelTransformation);
      final modelAnchorId = await anchorManager.addAnchor(modelAnchor);

      if (modelAnchorId == null) {
        debugPrint('Failed to add model anchor');
        return;
      }

      final node = ar_models.ARNode(
        type: ar_types.NodeType.localGLTF2,
        uri: modelPath,
        scale: vector.Vector3(kDefaultModelScale, kDefaultModelScale, kDefaultModelScale),
      );

      final nodeId = await objectManager.addNode(node, planeAnchor: modelAnchor);

      if (nodeId != null) {
        state.addNode(node);

        // Clean up reticle
        await objectManager.removeNode(_reticleNode!);
        await anchorManager.removeAnchor(_reticleAnchor!);
        _reticleNode = null;
        _reticleAnchor = null;
        _lastHitTransform = null;
        _currentReticleRotation = vector.Quaternion.identity();
        state.setReticleVisible(false);
      }
    } catch (e) {
      debugPrint('Error placing model: $e');
    }
  }

  /// Remove all placed models from the scene
  Future<void> removeAllModels() async {
    if (state.nodes.isEmpty) return;

    for (var node in List.from(state.nodes)) {
      try {
        await objectManager.removeNode(node);
      } catch (_) {}
    }
    state.clearNodes();
  }


  // ──────────────────────────────────────────────────────────────
  // Mode Switching (World AR <-> Face AR)
  // ──────────────────────────────────────────────────────────────

  /// Toggle between World AR and Face AR modes
  /// Returns true if switch was successful
  Future<bool> toggleMode() async {
    try {
      bool success;

      if (_currentMode == ArMode.world) {
        // Clean up World AR objects before switching
        await removeAllModels();
        await _removeReticleSilent();

        success = await sessionManager.switchToFaceAR();
        if (success) {
          _currentMode = ArMode.face;
          state.setMode(ArMode.face);
          _lastHitTransform = null;
          _currentReticleRotation = vector.Quaternion.identity();
        }
      } else {
        success = await sessionManager.switchToWorldAR();
        if (success) {
          _currentMode = ArMode.world;
          state.setMode(ArMode.world);
        }
      }

      return success;
    } catch (e) {
      debugPrint('Error toggling mode: $e');
      return false;
    }
  }

  /// Switch to Face AR mode with optional initial model and texture
  Future<bool> switchToFaceAR({String? faceModelPath, String? texturePath}) async {
    try {
      final success = await sessionManager.switchToFaceAR(
        modelPath: faceModelPath,
        texturePath: texturePath,
      );

      if (success) {
        _currentMode = ArMode.face;
        state.setMode(ArMode.face);
        await _removeReticleSilent();

        if (faceModelPath != null && faceModelPath.isNotEmpty) {
          await setFaceModel(faceModelPath);
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error switching to Face AR: $e');
      return false;
    }
  }

  /// Switch to World AR mode
  Future<bool> switchToWorldAR() async {
    try {
      final success = await sessionManager.switchToWorldAR();
      if (success) {
        _currentMode = ArMode.world;
        state.setMode(ArMode.world);
        _currentFaceModelPath = null;
      }
      return success;
    } catch (e) {
      debugPrint('Error switching to World AR: $e');
      return false;
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Face AR Models
  // ──────────────────────────────────────────────────────────────

  /// Set the 3D model for face filter
  /// Returns true if successful
  Future<bool> setFaceModel(String faceModelPath) async {
    try {
      if (faceModelPath.isEmpty) {
        return await clearFaceModel();
      }

      final success = await sessionManager.setFaceModel(modelPath: faceModelPath);

      if (success) {
        _currentFaceModelPath = faceModelPath;
      }

      return success;
    } catch (e) {
      debugPrint('Error setting face model: $e');
      return false;
    }
  }

  /// Clear the current face model
  Future<bool> clearFaceModel() async {
    try {
      final success = await sessionManager.clearFaceModel();
      if (success) {
        _currentFaceModelPath = null;
      }
      return success;
    } catch (e) {
      debugPrint('Error clearing face model: $e');
      return false;
    }
  }

  /// Update face model path (convenience method for UI)
  Future<void> updateFaceModelPath(String newModelPath) async {
    if (_currentMode == ArMode.face) {
      await setFaceModel(newModelPath);
    } else {
      _currentFaceModelPath = newModelPath;
    }
  }

  /// Add a 3D model to a specific face region
  /// [region] can be: 'nose', 'forehead', 'leftEye', 'rightEye'
  Future<bool> addModelToFace({
    required String modelUri,
    ar_types.NodeType type = ar_types.NodeType.localGLTF2,
    vector.Vector3? scale,
    String region = 'nose',
  }) async {
    if (_currentMode != ArMode.face) {
      debugPrint('Cannot add model to face: not in Face AR mode');
      return false;
    }

    try {
      final node = ar_models.ARNode(
        type: type,
        uri: modelUri,
        scale: scale ?? vector.Vector3(0.1, 0.1, 0.1),
      );

      final result = await objectManager.addNodeToFace(node, region: region);
      if (result != null) {
        state.addNode(node);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding model to face: $e');
      return false;
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Callbacks Setup
  // ──────────────────────────────────────────────────────────────

  /// Set up Face AR callbacks for face detection and pose updates
  void setupFaceARCallbacks({
    Function(bool detected)? onFaceDetected,
    Function(Map<String, dynamic> pose)? onFacePoseUpdate,
    Function(ArMode mode)? onModeChanged,
  }) {
    sessionManager.onFaceDetected = (detected) {
      state.setFaceDetected(detected);
      onFaceDetected?.call(detected);
    };

    sessionManager.onFacePoseUpdate = (pose) {
      state.updateFacePose(pose);
      onFacePoseUpdate?.call(pose);
    };

    sessionManager.onModeChanged = (modeStr) {
      _currentMode = ArModeExtension.fromString(modeStr);
      state.setMode(_currentMode);
      onModeChanged?.call(_currentMode);
    };
  }


  // ──────────────────────────────────────────────────────────────
  // Cleanup
  // ──────────────────────────────────────────────────────────────

  /// Dispose of AR resources
  void dispose() {
    try {
      _removeReticleSilent();
      sessionManager.dispose();
    } catch (_) {}
  }
}
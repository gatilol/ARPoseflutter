import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
// Utiliser les imports spécifiques pour éviter les conflits
import 'package:ar_flutter_plugin_2/models/ar_node.dart' as ar_models;
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart' as ar_types;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:flutter/foundation.dart';
import 'dart:math' as math; 

import '../models/ar_state.dart';
import '../models/ar_mode.dart';

class ARService {
  late ARSessionManager sessionManager;
  late ARObjectManager objectManager;
  late ARAnchorManager anchorManager;

  final ARState state;
  String modelPath;
  final String reticlePath;

  // internal tracking
  ar_models.ARNode? _reticleNode;
  ARPlaneAnchor? _reticleAnchor;
  
  // ✅ QUATERNION au lieu d'un simple angle
  vector.Quaternion _currentReticleRotation = vector.Quaternion.identity();
  vector.Matrix4? _lastHitTransform;

  // ========== Face AR State ==========
  ArMode _currentMode = ArMode.world;
  String? _currentFaceModelPath; // ← Track current face model
  ArMode get currentMode => _currentMode;
  bool get isWorldMode => _currentMode == ArMode.world;
  bool get isFaceMode => _currentMode == ArMode.face;
  String? get currentFaceModelPath => _currentFaceModelPath;
  // ====================================

  ARService({
    required this.state,
    required this.modelPath,
    required this.reticlePath,
  });

  void updateModelPath(String newModelPath) {
    modelPath = newModelPath;
    debugPrint('Model path updated to: $newModelPath');
  }

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
    
    // Setup Face AR callbacks
    setupFaceARCallbacks();
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    final ARHitTestResult planeHit = hits.firstWhere(
          (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    _lastHitTransform = planeHit.worldTransform;
    
    // ✅ Réinitialiser le quaternion
    _currentReticleRotation = vector.Quaternion.identity();
    
    await _updateReticleWithRotation();
  }

  Future<void> _updateReticleWithRotation() async {
    if (_lastHitTransform == null) return;

    await _removeReticleSilent();

    var anchorTransformation = _lastHitTransform!;

    // ✅ CHANGEMENT ICI : Matrix4 au lieu de Matrix3
    final rotationMatrix = vector.Matrix4.identity();
    rotationMatrix.setRotation(_currentReticleRotation.asRotationMatrix());
    
    // Debug : afficher l'angle
    final angleRadians = _currentReticleRotation.radians;
    final angleDegrees = angleRadians * 180 / math.pi;
    debugPrint('🔄 Angle: ${angleDegrees.toStringAsFixed(1)}° (${angleRadians.toStringAsFixed(3)} rad)');
    debugPrint('📐 Quaternion: x=${_currentReticleRotation.x.toStringAsFixed(3)}, '
          'y=${_currentReticleRotation.y.toStringAsFixed(3)}, '
          'z=${_currentReticleRotation.z.toStringAsFixed(3)}, '
          'w=${_currentReticleRotation.w.toStringAsFixed(3)}');

    // Appliquer la rotation
    anchorTransformation = anchorTransformation * rotationMatrix;

    debugPrint('📍 Transformation: ${anchorTransformation.getTranslation()}');
    
    final anchor = ARPlaneAnchor(transformation: anchorTransformation);

    final anchorId = await anchorManager.addAnchor(anchor);
    if (anchorId == null) {
      debugPrint('❌ Anchor failed!');
      return;
    }

    final reticleNode = ar_models.ARNode(
      type: ar_types.NodeType.localGLTF2,
      uri: reticlePath,
      scale: vector.Vector3(0.15, 0.15, 0.15),
    );

    final nodeId = await objectManager.addNode(reticleNode, planeAnchor: anchor);

    if (nodeId != null) {
      _reticleNode = reticleNode;
      _reticleAnchor = anchor;
      state.setReticleVisible(true);
      debugPrint('✅ Reticle créé!');
    } else {
      debugPrint('❌ Node failed!');
      try {
        await anchorManager.removeAnchor(anchor);
      } catch (_) {}
    }
  }

  // ✅ ROTATION AVEC QUATERNIONS
  Future<void> rotateReticle(double angleRadians) async {
    if (_reticleNode == null || _lastHitTransform == null) return;
    
    debugPrint('⚙️ AVANT rotation:');
    debugPrint('   Quaternion: x=${_currentReticleRotation.x}, y=${_currentReticleRotation.y}, z=${_currentReticleRotation.z}, w=${_currentReticleRotation.w}');
    
    // Créer un quaternion représentant la rotation incrémentale autour de l'axe Y
    final rotationAxis = vector.Vector3(0.0, 1.0, 0.0);
    final deltaRotation = vector.Quaternion.axisAngle(rotationAxis, angleRadians);
    
    debugPrint('   Delta rotation: x=${deltaRotation.x}, y=${deltaRotation.y}, z=${deltaRotation.z}, w=${deltaRotation.w}');
    
    // Multiplication de quaternions
    _currentReticleRotation = _currentReticleRotation * deltaRotation;
    
    debugPrint('⚙️ APRÈS multiplication:');
    debugPrint('   Quaternion: x=${_currentReticleRotation.x}, y=${_currentReticleRotation.y}, z=${_currentReticleRotation.z}, w=${_currentReticleRotation.w}');
    
    // Normaliser
    _currentReticleRotation.normalize();
    
    debugPrint('⚙️ APRÈS normalisation:');
    debugPrint('   Quaternion: x=${_currentReticleRotation.x}, y=${_currentReticleRotation.y}, z=${_currentReticleRotation.z}, w=${_currentReticleRotation.w}');
    
    // Debug
    final totalAngle = _currentReticleRotation.radians * 180 / math.pi;
    debugPrint('✅ Rotation totale: ${totalAngle.toStringAsFixed(1)}°');
    
    await _updateReticleWithRotation();
  }

  Future<void> placeModelAtReticle() async {
    if (_reticleAnchor == null || _lastHitTransform == null) return;

    try {
      var modelTransformation = _lastHitTransform!;

      debugPrint('📍 Position hit: ${_lastHitTransform!.getTranslation()}');
      
      // ✅ CHANGEMENT ICI : Matrix4 au lieu de Matrix3
      final rotationMatrix = vector.Matrix4.identity();
      rotationMatrix.setRotation(_currentReticleRotation.asRotationMatrix());
      
      final angleRadians = _currentReticleRotation.radians;
      final angleDegrees = angleRadians * 180 / math.pi;
      debugPrint('🎯 Placement avec rotation: ${angleDegrees.toStringAsFixed(1)}°');
      
      modelTransformation = modelTransformation * rotationMatrix;

      debugPrint('🎯 Transformation finale: ${modelTransformation.storage}');
      
      final modelAnchor = ARPlaneAnchor(transformation: modelTransformation);
      final modelAnchorId = await anchorManager.addAnchor(modelAnchor);
      
      if (modelAnchorId == null) {
        debugPrint('Failed to add model anchor');
        return;
      }

      final node = ar_models.ARNode(
        type: ar_types.NodeType.localGLTF2,
        uri: modelPath,
        scale: vector.Vector3(1.0, 1.0, 1.0),
      );

      final nodeId = await objectManager.addNode(node, planeAnchor: modelAnchor);

      if (nodeId != null) {
        state.addNode(node);

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

  Future<void> removeAllModels() async {
    if (state.nodes.isEmpty) return;
    for (var node in List.from(state.nodes)) {
      try {
        await objectManager.removeNode(node);
      } catch (_) {}
    }
    state.clearNodes();
  }

  void dispose() {
    try {
      _removeReticleSilent();
      sessionManager.dispose();
    } catch (_) {}
  }

  // ==================================================================================
  // ========================= FACE AR METHODS ========================================
  // ==================================================================================

  /// Toggle between World AR and Face AR modes
  /// Returns true if switch was successful
  Future<bool> toggleMode() async {
    try {
      bool success;
      
      if (_currentMode == ArMode.world) {
        // Passer en Face AR
        success = await sessionManager.switchToFaceAR();
        if (success) {
          _currentMode = ArMode.face;
          state.setMode(ArMode.face);
          await _removeReticleSilent();
          _lastHitTransform = null;
          _currentReticleRotation = vector.Quaternion.identity();
        }
      } else {
        // Passer en World AR
        success = await sessionManager.switchToWorldAR();
        if (success) {
          _currentMode = ArMode.world;
          state.setMode(ArMode.world);
        }
      }
      
      debugPrint('✅ Mode switched to: $_currentMode (success: $success)');
      return success;
    } catch (e) {
      debugPrint('❌ Error toggling mode: $e');
      return false;
    }
  }

  /// Switch to Face AR mode
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
        
        // Load model if provided
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

  // ==================================================================================
  // ========================= SET FACE MODEL =========================================
  // ==================================================================================

  /// Set the 3D model for face filter
  /// [modelPath] - Path to the GLB model in Flutter assets (e.g., 'assets/models/fox.glb')
  /// Returns true if successful
  Future<bool> setFaceModel(String faceModelPath) async {
    try {
      debugPrint('🦊 Setting face model: $faceModelPath');
      
      // If empty path, clear the model
      if (faceModelPath.isEmpty) {
        return await clearFaceModel();
      }
      
      final success = await sessionManager.setFaceModel(modelPath: faceModelPath);
      
      if (success) {
        _currentFaceModelPath = faceModelPath;
        debugPrint('✅ Face model set successfully: $faceModelPath');
      } else {
        debugPrint('❌ Failed to set face model');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error setting face model: $e');
      return false;
    }
  }

  /// Clear the current face model (remove filter)
  Future<bool> clearFaceModel() async {
    try {
      debugPrint('🧹 Clearing face model');
      final success = await sessionManager.clearFaceModel();
      if (success) {
        _currentFaceModelPath = null;
        debugPrint('✅ Face model cleared');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error clearing face model: $e');
      return false;
    }
  }

  /// Update face model path (convenience method for UI)
  Future<void> updateFaceModelPath(String newModelPath) async {
    if (_currentMode == ArMode.face) {
      await setFaceModel(newModelPath);
    } else {
      // Store for later use when switching to Face AR
      _currentFaceModelPath = newModelPath;
    }
  }

  // ==================================================================================

  /// Add a 3D model to the detected face
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

  /// Set up Face AR callbacks
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

  // ==================================================================================
}
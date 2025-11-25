import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:flutter/foundation.dart';
import 'dart:math' as math; 

import '../models/ar_state.dart';

class ARService {
  late ARSessionManager sessionManager;
  late ARObjectManager objectManager;
  late ARAnchorManager anchorManager;

  final ARState state;
  String modelPath; // ← NON final pour pouvoir changer (ajout collègue)
  final String reticlePath;

  // internal tracking
  ARNode? _reticleNode;
  ARPlaneAnchor? _reticleAnchor;
  
  // ✨ CHANGEMENT: Utilisation d'un Quaternion au lieu d'un angle
  vector.Quaternion _currentReticleRotation = vector.Quaternion.identity();
  vector.Matrix4? _lastHitTransform;

  ARService({
    required this.state,
    required this.modelPath,
    required this.reticlePath,
  });

  // : Met à jour le chemin du modèle
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
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    final ARHitTestResult planeHit = hits.firstWhere(
          (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    _lastHitTransform = planeHit.worldTransform;
    
    // ✨ CHANGEMENT: Réinitialiser le quaternion à l'identité
    _currentReticleRotation = vector.Quaternion.identity();
    
    await _updateReticleWithRotation();
  }

  Future<void> _updateReticleWithRotation() async {
    if (_lastHitTransform == null) return;

    await _removeReticleSilent();

    var anchorTransformation = _lastHitTransform!;

    // ✨ CHANGEMENT: Conversion du quaternion en matrice de rotation
    final rotationMatrix = _currentReticleRotation.asRotationMatrix();
    
    // Debug: Afficher l'angle actuel (extrait du quaternion)
    final angleRadians = _currentReticleRotation.radians;
    final angleDegrees = angleRadians * 180 / math.pi;
    print('🔄 Angle: ${angleDegrees.toStringAsFixed(1)}° (${angleRadians.toStringAsFixed(3)} rad)');
    print('📐 Quaternion: x=${_currentReticleRotation.x.toStringAsFixed(3)}, y=${_currentReticleRotation.y.toStringAsFixed(3)}, z=${_currentReticleRotation.z.toStringAsFixed(3)}, w=${_currentReticleRotation.w.toStringAsFixed(3)}');

    // Appliquer la rotation
    anchorTransformation = anchorTransformation * rotationMatrix;

    // 🔍 DEBUG: Vérifier la transformation finale
    print('📍 Transformation: ${anchorTransformation.getTranslation()}');
    
    final anchor = ARPlaneAnchor(transformation: anchorTransformation);

    final anchorId = await anchorManager.addAnchor(anchor);
    if (anchorId == null) {
      print('❌ Anchor failed!');
      return;
    }

    final reticleNode = ARNode(
      type: NodeType.localGLTF2,
      uri: reticlePath,
      scale: vector.Vector3(0.15, 0.15, 0.15),
    );

    final nodeId = await objectManager.addNode(reticleNode, planeAnchor: anchor);

    if (nodeId != null) {
      _reticleNode = reticleNode;
      _reticleAnchor = anchor;
      state.setReticleVisible(true);
      print('✅ Reticle créé!');
    } else {
      print('❌ Node failed!');
      try {
        await anchorManager.removeAnchor(anchor);
      } catch (_) {}
    }
  }

  // ✨ CHANGEMENT: Rotation avec quaternions
  Future<void> rotateReticle(double angleRadians) async {
    if (_reticleNode == null || _lastHitTransform == null) return;
    
    // Créer un quaternion représentant la rotation incrémentale autour de l'axe Y
    final rotationAxis = vector.Vector3(0.0, 1.0, 0.0);
    final deltaRotation = vector.Quaternion.axisAngle(rotationAxis, angleRadians);
    
    // ✨ MULTIPLICATION DE QUATERNIONS: plus précis que l'addition d'angles d'Euler
    // L'ordre est important: nouvellRotation = ancienneRotation * deltaRotation
    _currentReticleRotation = _currentReticleRotation * deltaRotation;
    
    // Normaliser pour éviter l'accumulation d'erreurs numériques
    _currentReticleRotation.normalize();
    
    // Debug
    final totalAngle = _currentReticleRotation.radians * 180 / math.pi;
    print('✅ Rotation totale: ${totalAngle.toStringAsFixed(1)}°');
    
    await _updateReticleWithRotation();
  }

  Future<void> placeModelAtReticle() async {
    if (_reticleAnchor == null || _lastHitTransform == null) return;

    try {
      var modelTransformation = _lastHitTransform!;

      // 🔍 DEBUG: Vérifier que _lastHitTransform n'a pas changé
      print('📍 Position hit: ${_lastHitTransform!.getTranslation()}');
      
      // ✨ CHANGEMENT: Conversion du quaternion en matrice
      final rotationMatrix = _currentReticleRotation.asRotationMatrix();
      
      final angleRadians = _currentReticleRotation.radians;
      final angleDegrees = angleRadians * 180 / math.pi;
      print('🎯 Placement avec rotation: ${angleDegrees.toStringAsFixed(1)}°');
      print('📐 Quaternion final: x=${_currentReticleRotation.x.toStringAsFixed(3)}, y=${_currentReticleRotation.y.toStringAsFixed(3)}, z=${_currentReticleRotation.z.toStringAsFixed(3)}, w=${_currentReticleRotation.w.toStringAsFixed(3)}');
      
      // Appliquer la rotation
      modelTransformation = modelTransformation * rotationMatrix;

      // 🔍 DEBUG: Vérifier la transformation finale
      print('🎯 Transformation finale: ${modelTransformation.storage}');
      
      final modelAnchor = ARPlaneAnchor(transformation: modelTransformation);
      final modelAnchorId = await anchorManager.addAnchor(modelAnchor);
      
      if (modelAnchorId == null) {
        debugPrint('Failed to add model anchor');
        return;
      }

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: modelPath,
        scale: vector.Vector3(0.4, 0.4, 0.4),
      );

      final nodeId = await objectManager.addNode(node, planeAnchor: modelAnchor);

      if (nodeId != null) {
        state.addNode(node);

        await objectManager.removeNode(_reticleNode!);
        await anchorManager.removeAnchor(_reticleAnchor!);
        _reticleNode = null;
        _reticleAnchor = null;
        _lastHitTransform = null;
        
        // ✨ CHANGEMENT: Réinitialiser le quaternion
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
}
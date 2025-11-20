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


import '../models/ar_state.dart';

class ARService {
  late ARSessionManager sessionManager;
  late ARObjectManager objectManager;
  late ARAnchorManager anchorManager;

  final ARState state;
  final String modelPath;    // modèle final (eva_01_esg.glb)
  final String reticlePath;  // reticle.glb

  // internal tracking
  ARNode? _reticleNode;
  ARPlaneAnchor? _reticleAnchor;
  // String? _reticleAnchorId; //mis en com car par utiliser pour l'instant

  ARService({
    required this.state,
    required this.modelPath,
    required this.reticlePath,
  });

  // à brancher sur onARViewCreated
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

    // IMPORTANT : onPlaneOrPointTap est appelé sur chaque tap
    sessionManager.onPlaneOrPointTap = (hits) => onPlaneOrPointTapped(hits);
  }

  // Quand l'utilisateur tap l'écran : on déplace le reticle (ne place pas le modèle)
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    // Choisir un hit (priorité aux planes)
    final ARHitTestResult planeHit = hits.firstWhere(
          (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    // if (planeHit == null) return;  //jamais null alors ne sert a rien

    // Create anchor for reticle at hit transform
    final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);

    // Remove previous reticle anchor+node if exists
    await _removeReticleSilent();

    final anchorId = await anchorManager.addAnchor(anchor);
    if (anchorId == null) {
      // can't add anchor
      return;
    }

    // create reticle node attached to the anchor
    final reticleNode = ARNode(
      type: NodeType.localGLTF2,
      uri: reticlePath,
      // tweak scale/rotation if needed
      scale: vector.Vector3(0.15, 0.15, 0.15),
      // You can also set eulerAngles/rotation if reticle needs rotation
    );

    final nodeId = await objectManager.addNode(reticleNode, planeAnchor: anchor);

    if (nodeId != null) {
      // save references
      _reticleNode = reticleNode;
      _reticleAnchor = anchor;
      //_reticleAnchorId = "reticle_anchor";      //ne sert a rien vu la mise en comme au dessus 

      // expose to UI via state
      state.setReticleVisible(true);
    } else {
      // fallback: remove anchor if node failed
      try {
        await anchorManager.removeAnchor(anchor);
      } catch (_) {}
    }
  }

  // Place the final model at reticle's anchor. Removes the reticle.
  Future<void> placeModelAtReticle() async {
    if (_reticleAnchor == null) {
      // nothing to place
      return;
    }

    try {
      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: modelPath,
        scale: vector.Vector3(0.4, 0.4, 0.4),
      );

      // attach final model to the SAME anchor used by the reticle
      final nodeId = await objectManager.addNode(node, planeAnchor: _reticleAnchor);

      if (nodeId != null) {
        // track final node in state (so removeAllModels can delete it)
        state.addNode(node);

        // remove reticle (we want it invisible until next tap)
        await objectManager.removeNode(_reticleNode!);
        _reticleNode = null;
        state.setReticleVisible(false);

        // Optionally provide haptic feedback
      }
    } catch (e) {
      // log but don't crash
      debugPrint('Error placing model: $e');
    }
  }

  // internal helper: remove reticle anchor+node without modifying state too much
  Future<void> _removeReticleSilent() async {
    // remove node first
    if (_reticleNode != null) {
      try {
        await objectManager.removeNode(_reticleNode!);
      } catch (_) {}
      _reticleNode = null;
    }

    // then remove anchor
    _reticleNode = null;

    // update state
    state.setReticleVisible(false);
  }

  // remove all final models (keeps reticle unaffected)
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
      // cleanup reticle
      _removeReticleSilent();
      sessionManager.dispose();
    } catch (_) {}
  }
}

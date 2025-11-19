import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/ar_state.dart';

class ARService {
  late ARSessionManager sessionManager;
  late ARObjectManager objectManager;
  late ARAnchorManager anchorManager;

  final ARState state;
  final String modelPath;

  ARService({required this.state, required this.modelPath});

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

    final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
    final anchorId = await anchorManager.addAnchor(anchor);
    if (anchorId == null) return;

    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: modelPath,
      scale: vector.Vector3(0.4, 0.4, 0.4),
    );

    final nodeId = await objectManager.addNode(node, planeAnchor: anchor);
    if (nodeId != null) {
      state.addNode(node);
    }
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
      sessionManager.dispose();
    } catch (_) {}
  }
}

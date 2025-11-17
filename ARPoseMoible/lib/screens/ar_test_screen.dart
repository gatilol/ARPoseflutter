import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

// ar_flutter_plugin_2 (v0.0.3)
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';

class ArTestScreen extends StatefulWidget {
  const ArTestScreen({super.key});

  @override
  State<ArTestScreen> createState() => _ArTestScreenState();
}

class _ArTestScreenState extends State<ArTestScreen> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  final String modelPath = "assets/models/eva_01_esg.glb"; // vérifie que ce fichier est listé dans pubspec.yaml

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Test')),
      body: ARView(
        // type de détection de plan (horizontal ici)
        planeDetectionConfig: PlaneDetectionConfig.horizontal,
        // callback OBLIGATOIRE : la signature attend 4 paramètres
        onARViewCreated: onARViewCreated,
      ),
    );
  }

  // Signature conforme à la doc : 4 params, même si tu n'utilises pas locationManager
  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager,
      ARLocationManager locationManager,
      ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    // Initialise la session (options courantes)
    // La méthode et les options existent dans l'API du package.
    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: false,
      handleRotation: false,
    );

    // Enregistre le callback pour les taps sur plan / points
    // Callback type : void Function(List<ARHitTestResult> hits)
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  // Callback appelé quand l'utilisateur tape sur l'écran et qu'on obtient des hit results
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    // On préfère une hit sur un plane si elle existe
    ARHitTestResult? planeHit = hits.firstWhere(
          (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    if (planeHit == null) return;

    // Créer une ancre basée sur la transformation renvoyée par le hit
    final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);

    // addAnchor retourne généralement un id (String?) ; vérifie la valeur de retour
    final anchorId = await arAnchorManager.addAnchor(anchor);
    if (anchorId == null) {
      debugPrint("Erreur : impossible d'ajouter l'ancre");
      return;
    }

    // Créer un noeud GLTF/GLB et l'attacher à l'ancre
    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: modelPath,
      scale: vector.Vector3(0.4, 0.4, 0.4),
      // position/rotation sont optionnels ; l'objet suit l'ancre
    );

    final nodeId = await arObjectManager.addNode(node, planeAnchor: anchor);
    if (nodeId == null) {
      debugPrint("Erreur : impossible d'ajouter le modèle");
    }
  }

  @override
  void dispose() {
    // Nettoyage (ferme la session native si besoin)
    try {
      arSessionManager.dispose();
    } catch (_) {}
    super.dispose();
  }
}

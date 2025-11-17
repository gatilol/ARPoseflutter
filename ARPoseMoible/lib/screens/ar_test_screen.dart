import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'dart:typed_data';

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

  /// Controller pour capturer le screenshot
  final ScreenshotController screenshotController = ScreenshotController();

  /// Liste des modèles dans la scène
  List<ARNode> placedNodes = [];

  /// Chemin du modèle 3D
  final String modelPath = "assets/models/eva_01_esg.glb";

  /// Indique si on a placé au moins un modèle
  bool hasPlacedModel = false;

  /// Indique si on est en train de prendre une photo (pour masquer les overlays)
  bool isCapturingPhoto = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Screenshot(
        controller: screenshotController,
        child: Stack(
          children: [
            // Vue AR
            ARView(
              onARViewCreated: onARViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.horizontal,
            ),

            // === OVERLAYS (masqués pendant la capture) ===
            if (!isCapturingPhoto) ...[
              // Gradient en haut
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bouton retour
              Positioned(
                top: 50,
                left: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),

              // Instructions
              if (!hasPlacedModel)
                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Touchez une surface pour\nplacer le modèle 3D',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Gradient en bas
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Boutons en bas
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      // Bouton Photo (plus grand)
                      _buildCircleButton(
                        icon: Icons.camera_alt,
                        onPressed: _takePhoto,
                        size: 80,
                        isPrimary: true,
                      ),

                      // Espace vide pour équilibrer
                      const SizedBox(width: 60),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: false,
      handleRotation: false,
    );

    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;

    ARHitTestResult? planeHit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    if (planeHit == null) return;

    final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
    final anchorId = await arAnchorManager.addAnchor(anchor);

    if (anchorId == null) {
      debugPrint("❌ Impossible d'ajouter l'ancre");
      return;
    }

    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: modelPath,
      scale: vector.Vector3(0.4, 0.4, 0.4),
    );

    final nodeId = await arObjectManager.addNode(node, planeAnchor: anchor);

    if (nodeId != null) {
      placedNodes.add(node);
      setState(() {
        hasPlacedModel = true;
      });
      HapticFeedback.mediumImpact();
      debugPrint("✅ Modèle placé !");
    } else {
      debugPrint("❌ Impossible d'ajouter le modèle");
    }
  }


  /// Prendre une photo de la scène AR et l'enregistrer dans la galerie
  Future<void> _takePhoto() async {
    try {
      // 1. Masquer les overlays
      setState(() {
        isCapturingPhoto = true;
      });

      // 2. Attendre un peu pour que l'UI se mette à jour
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Lancer la capture
      final captureFuture = screenshotController.capture();

      // 4. Attendre que la capture commence vraiment
      await Future.delayed(const Duration(milliseconds: 500));

      // 5. Réafficher les overlays maintenant
      setState(() {
        isCapturingPhoto = false;
      });

      // 6. Attendre le résultat de la capture
      final Uint8List? imageBytes = await captureFuture;

      if (imageBytes == null) {
        throw Exception('Impossible de capturer l\'écran');
      }

      // 7. Sauvegarder dans la galerie
      await _savePhotoToGallery(imageBytes);

      // 8. Feedback tactile
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        isCapturingPhoto = false;
      });

      debugPrint('❌ Erreur photo: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Sauvegarder la photo dans la galerie
  Future<void> _savePhotoToGallery(Uint8List imageBytes) async {
    try {
      // 1. Créer un fichier temporaire
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      debugPrint('📁 Fichier temporaire créé : $imagePath');

      // 2. Sauvegarder dans la galerie via Gal
      await Gal.putImage(imagePath);

      debugPrint('✅ Photo sauvegardée dans la galerie !');

      // 3. Confirmation visuelle
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Photo AR enregistrée dans la galerie !'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 4. Optionnel : Retourner le résultat au WebView
      // Décommentez si vous voulez informer le WebView
      /*
      if (mounted) {
        Navigator.pop(context, {
          'imagePath': imagePath,
          'timestamp': timestamp,
          'savedToGallery': true,
        });
      }
      */
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement dans la galerie'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Widget pour créer les boutons ronds
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.white
                : (color ?? Colors.white).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary ? Colors.blue : (color ?? Colors.white),
              width: isPrimary ? 4 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? Colors.blue
                : (color ?? Colors.black87),
            size: isPrimary ? 40 : 28,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      arSessionManager.dispose();
    } catch (_) {}
    super.dispose();
  }
}
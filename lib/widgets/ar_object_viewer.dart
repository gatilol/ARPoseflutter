import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/ar_object_config.dart';

/// Widget pour afficher un modèle 3D GLB avec model_viewer_plus
class ARObjectViewer extends StatefulWidget {
  final ARObjectConfig config;
  
  const ARObjectViewer({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  State<ARObjectViewer> createState() => _ARObjectViewerState();
}

class _ARObjectViewerState extends State<ARObjectViewer> {
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    print('🔍 Chargement du modèle avec model_viewer_plus : ${widget.config.modelPath}');
    
    // Simuler un délai de chargement
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoading = false);
        print('✅ Modèle initialisé avec model_viewer_plus !');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 350,
        height: 350,
        child: Stack(
          children: [
            // ModelViewer principal
            ModelViewer(
              src: widget.config.modelPath,
              alt: 'Modèle 3D AR',
              autoRotate: widget.config.autoRotate,
              cameraControls: false,
              disableZoom: true,
              backgroundColor: Colors.transparent,
              
              // Paramètres de caméra
              cameraOrbit: '0deg 75deg 2.5m',
              fieldOfView: '30deg',
              
              // Éclairage
              shadowIntensity: 0.5,
              shadowSoftness: 0.8,
            ),
            
            // Indicateur de chargement
            if (_isLoading)
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Chargement 3D...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
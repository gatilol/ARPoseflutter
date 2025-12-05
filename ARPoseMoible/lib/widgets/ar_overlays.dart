import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/ar_state.dart';
import 'circle_button.dart';

class AROverlays extends StatelessWidget {
  final ARState state;
  final VoidCallback onClose;
  final VoidCallback onTakePhoto;
  final VoidCallback onDelete;
  final VoidCallback onPlaceModel;
  final VoidCallback onOpenModelMenu;
  final Future<void> Function(double) onRotateReticle;
  // ========== Callbacks pour switch caméra ==========
  final VoidCallback? onSwitchCamera;
  final bool isSwitchingCamera;
  // ==================================================

  const AROverlays({
    required this.state,
    required this.onClose,
    required this.onTakePhoto,
    required this.onDelete,
    required this.onPlaceModel,
    required this.onOpenModelMenu,
    required this.onRotateReticle,
    this.onSwitchCamera,
    this.isSwitchingCamera = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isCapturing) return const SizedBox.shrink();

    return Stack(
      children: [
        // Top gradient
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
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent
                ]
              )
            )
          )
        ),

        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle
                ),
                child: const Icon(Icons.close, color: Colors.white)
              ),
            ),
          ),
        ),

        // ========== Bouton menu des modèles (World AR ET Face AR) ==========
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenModelMenu,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  // Couleur différente selon le mode
                  color: state.isWorldMode 
                    ? Colors.blue.withValues(alpha: 0.8)
                    : Colors.purple.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (state.isWorldMode ? Colors.blue : Colors.purple).withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                // Icône différente selon le mode
                child: Icon(
                  state.isWorldMode ? Icons.view_in_ar : Icons.face_retouching_natural,
                  color: Colors.white
                )
              ),
            ),
          ),
        ),
        // ===================================================================

        // Boutons de rotation (seulement en World AR avec reticle visible)
        if (state.isWorldMode && state.reticleVisible) ...[
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'rotateLeft',
              mini: true,
              onPressed: () async {
                await onRotateReticle(-math.pi / 8);
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.rotate_left),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'rotateRight',
              mini: true,
              onPressed: () async {
                await onRotateReticle(math.pi / 8);
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.rotate_right),
            ),
          ),
        ],

        // Instructions World AR - DÉSACTIVÉ
        //         if (state.isWorldMode && !state.hasPlacedModel)
        //           Positioned(
        //             top: MediaQuery.of(context).padding.top + 150,
        //             left: 0,
        //             right: 0,
        //             child: Center(
        //               child: Container(
        //                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        //                 margin: const EdgeInsets.symmetric(horizontal: 32),
        //                 decoration: BoxDecoration(
        //                   color: Colors.black.withValues(alpha: 0.7),
        //                   borderRadius: BorderRadius.circular(20),
        //                   border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        //                 ),
        //                 child: const Column(
        //                   mainAxisSize: MainAxisSize.min,
        //                   children: [
        //                     Icon(Icons.touch_app, color: Colors.white, size: 32),
        //                     SizedBox(height: 8),
        //                     Text(
        //                       'Touchez une surface pour\nplacer le modèle 3D',
        //                       textAlign: TextAlign.center,
        //                       style: TextStyle(
        //                         color: Colors.white,
        //                         fontSize: 14,
        //                         fontWeight: FontWeight.bold
        //                       )
        //                     )
        //                   ]
        //                 ),
        //               )
        //             ),
        //           ),

        // Bottom gradient
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
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent
                ]
              )
            )
          )
        ),

        // ========== Bouton Switch Caméra ==========
        Positioned(
          bottom: 120,
          right: 23,
          child: _buildSwitchCameraButton(context),
        ),
        // ==========================================

        // Photo button (centre)
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: CircleButton(
              icon: Icons.camera_alt,
              onPressed: onTakePhoto,
              size: 80,
              isPrimary: true
            )
          )
        ),

        // Delete button (droite)
        Positioned(
          bottom: 50,
          right: 20,
          child: FloatingActionButton(
            heroTag: 'delete',
            onPressed: onDelete,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete)
          )
        ),

        // Place model button (gauche) - seulement en World AR
        if (state.isWorldMode)
          Positioned(
            bottom: 50,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'placeModel',
              onPressed: onPlaceModel,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add_location_alt)
            )
          ),

        // ========== Indicateur de mode actuel ==========
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(
            child: _buildModeIndicator(),
          ),
        ),
        // ===============================================
      ],
    );
  }

  /// Construit le bouton de switch caméra
  Widget _buildSwitchCameraButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSwitchingCamera ? null : onSwitchCamera,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSwitchingCamera 
              ? Colors.grey.withValues(alpha: 0.6)
              : Colors.orange.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: isSwitchingCamera
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            // ========== ICÔNE FIXE : cameraswitch ==========
            : const Icon(
                Icons.cameraswitch,
                color: Colors.white,
              ),
            // ===============================================
        ),
      ),
    );
  }

  /// Construit l'indicateur de mode actuel
  Widget _buildModeIndicator() {
    final isWorldMode = state.isWorldMode;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWorldMode ? Icons.view_in_ar : Icons.face,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isWorldMode ? 'World AR' : 'Face AR',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
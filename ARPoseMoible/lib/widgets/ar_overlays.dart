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
  final VoidCallback onOpenModelMenu; //
  final Future<void> Function(double) onRotateReticle;

  const AROverlays({
    required this.state,
    required this.onClose,
    required this.onTakePhoto,
    required this.onDelete,
    required this.onPlaceModel,
    required this.onOpenModelMenu, //
    required this.onRotateReticle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isCapturing) return const SizedBox.shrink();

    return Stack(
      children: [
        // top gradient
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

        // close button
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

        // : Bouton pour ouvrir le menu des modèles
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
                    color: Colors.blue.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.view_in_ar, color: Colors.white)
              ),
            ),
          ),
        ),

        // Boutons de rotation
        if (state.reticleVisible) ...[
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
              child: Icon(Icons.rotate_left),
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
              child: Icon(Icons.rotate_right),
            ),
          ),
        ],

        // instructions
        if (!state.hasPlacedModel)
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            left: 0,
            right: 0,
            child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                                fontWeight: FontWeight.bold
                            )
                        )
                      ]
                  ),
                )
            ),
          ),

        // bottom gradient
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

        // photo button
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

        // delete button
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

        // place model button
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
      ],
    );
  }
}
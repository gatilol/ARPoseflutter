import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/ar_state.dart';
import 'circle_button.dart';

/// AR overlay controls displayed on top of the AR view
class AROverlays extends StatelessWidget {
  final ARState state;
  final VoidCallback onClose;
  final VoidCallback onTakePhoto;
  final VoidCallback onDelete;
  final VoidCallback onPlaceModel;
  final VoidCallback onOpenModelMenu;
  final Future<void> Function(double) onRotateReticle;

  // Camera switch callbacks
  final VoidCallback? onSwitchCamera;
  final bool isSwitchingCamera;

  // Augmented Image 3D callbacks
  final bool isAugmentedImageDetected;
  final bool isAugmentedImage3DActive;
  final VoidCallback? onToggleAugmentedImage3D;

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
    this.isAugmentedImageDetected = false,
    this.isAugmentedImage3DActive = false,
    this.onToggleAugmentedImage3D,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Hide all overlays during photo capture
    if (state.isCapturing) return const SizedBox.shrink();

    return Stack(
      children: [
        // Top gradient
        _buildTopGradient(),

        // Close button (top left)
        _buildCloseButton(context),

        // Model menu button (top right)
        _buildModelMenuButton(context),

        // Rotation buttons (World AR only, when reticle visible)
        if (state.isWorldMode && state.reticleVisible) ...[
          _buildRotateLeftButton(context),
          _buildRotateRightButton(context),
        ],

        // Bottom gradient
        _buildBottomGradient(),

        // Augmented Image 3D button (above camera switch)
        if (state.isWorldMode && isAugmentedImageDetected)
          _buildAugmentedImage3DButton(context),

        // Camera switch button
        _buildSwitchCameraButton(context),

        // Photo button (center bottom)
        _buildPhotoButton(),

        // Delete button (right bottom)
        _buildDeleteButton(),

        // Place model button (left bottom, World AR only)
        if (state.isWorldMode) _buildPlaceModelButton(),

        // Mode indicator (center, above bottom controls)
        _buildModeIndicator(),
      ],
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Gradients
  // ──────────────────────────────────────────────────────────────

  Widget _buildTopGradient() {
    return Positioned(
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
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned(
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
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Top Buttons
  // ──────────────────────────────────────────────────────────────

  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
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
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildModelMenuButton(BuildContext context) {
    return Positioned(
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
              color: state.isWorldMode
                  ? Colors.blue.withValues(alpha: 0.8)
                  : Colors.purple.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (state.isWorldMode ? Colors.blue : Colors.purple)
                      .withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              state.isWorldMode ? Icons.view_in_ar : Icons.face_retouching_natural,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Rotation Buttons
  // ──────────────────────────────────────────────────────────────

  Widget _buildRotateLeftButton(BuildContext context) {
    return Positioned(
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
    );
  }

  Widget _buildRotateRightButton(BuildContext context) {
    return Positioned(
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
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Bottom Buttons
  // ──────────────────────────────────────────────────────────────

  Widget _buildPhotoButton() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Center(
        child: CircleButton(
          icon: Icons.camera_alt,
          onPressed: onTakePhoto,
          size: 80,
          isPrimary: true,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      bottom: 50,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'delete',
        onPressed: onDelete,
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete),
      ),
    );
  }

  Widget _buildPlaceModelButton() {
    return Positioned(
      bottom: 50,
      left: 20,
      child: FloatingActionButton(
        heroTag: 'placeModel',
        onPressed: onPlaceModel,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Camera Switch Button
  // ──────────────────────────────────────────────────────────────

  Widget _buildSwitchCameraButton(BuildContext context) {
    return Positioned(
      bottom: 120,
      right: 23,
      child: Material(
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
                : const Icon(Icons.cameraswitch, color: Colors.white),
          ),
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Augmented Image 3D Button
  // ──────────────────────────────────────────────────────────────

  Widget _buildAugmentedImage3DButton(BuildContext context) {
    return Positioned(
      bottom: 180,
      right: 23,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleAugmentedImage3D,
          borderRadius: BorderRadius.circular(25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isAugmentedImage3DActive
                  ? Colors.green.withValues(alpha: 0.9)
                  : Colors.cyan.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isAugmentedImage3DActive ? Colors.green : Colors.cyan)
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              isAugmentedImage3DActive
                  ? Icons.view_in_ar
                  : Icons.view_in_ar_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Mode Indicator
  // ──────────────────────────────────────────────────────────────

  Widget _buildModeIndicator() {
    final isWorldMode = state.isWorldMode;

    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
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
        ),
      ),
    );
  }
}
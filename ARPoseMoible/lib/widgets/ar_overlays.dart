import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/ar_state.dart';
import 'circle_button.dart';
import 'hexagon_button.dart';

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
        if (state.isWorldMode && state.reticleVisible) _buildPlaceModelButton(),

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
      child: HexagonButton(
        icon: Icons.home,
        onPressed: onClose,
        backgroundColor: Colors.red.withOpacity(0.8),
        size: 50,
      ),
    );
  }

  Widget _buildModelMenuButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: HexagonButton(
        icon: state.isWorldMode ? Icons.view_in_ar : Icons.face_retouching_natural,
        onPressed: onOpenModelMenu,
        backgroundColor: state.isWorldMode
            ? Colors.blue.withOpacity(0.8)
            : Colors.purple.withOpacity(0.8),
        size: 50,
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
      child: HexagonButton(
        icon: Icons.rotate_left,
        onPressed: () async {
          await onRotateReticle(-math.pi / 8);
        },
        backgroundColor: Colors.purple.withOpacity(0.8),
        size: 45,
      ),
    );
  }

  Widget _buildRotateRightButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      right: 20,
      child: HexagonButton(
        icon: Icons.rotate_right,
        onPressed: () async {
          await onRotateReticle(math.pi / 8);
        },
        backgroundColor: Colors.purple.withOpacity(0.8),
        size: 45,
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Bottom Buttons
  // ──────────────────────────────────────────────────────────────

  Widget _buildPhotoButton() {
    return Positioned(
      bottom: 70,
      left: 0,
      right: 0,
      child: Center(
        child: HexagonButton(
          icon: Icons.camera_alt,
          onPressed: onTakePhoto,
          backgroundColor: state.isWorldMode
              ? Colors.purple.withOpacity(0.9)
              : Colors.blue.withOpacity(0.9),
          size: 80,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      bottom: 70,
      right: 20,
      child: HexagonButton(
        icon: Icons.delete,
        onPressed: onDelete,
        backgroundColor: Colors.red.withOpacity(0.8),
        size: 55,
      ),
    );
  }

  Widget _buildPlaceModelButton() {
    return Positioned(
      bottom: 70,
      left: 20,
      child: HexagonButton(
        icon: Icons.add_location_alt,
        onPressed: onPlaceModel,
        backgroundColor: Colors.blue.withOpacity(0.8),
        size: 55,
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Camera Switch Button
  // ──────────────────────────────────────────────────────────────

  Widget _buildSwitchCameraButton(BuildContext context) {
    return Positioned(
      bottom: 130,
      right: 23,
      child: HexagonButton(
        icon: isSwitchingCamera ? Icons.hourglass_empty : Icons.cameraswitch,
        onPressed: isSwitchingCamera ? null : onSwitchCamera,
        backgroundColor: isSwitchingCamera
            ? Colors.grey.withOpacity(0.6)
            : state.isWorldMode
              ? Colors.blue.withOpacity(0.8)
              : Colors.purple.withOpacity(0.8),
        size: 50,
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
      child: HexagonButton(
        icon: isAugmentedImage3DActive
            ? Icons.view_in_ar
            : Icons.view_in_ar_outlined,
        onPressed: onToggleAugmentedImage3D,
        backgroundColor: isAugmentedImage3DActive
            ? Colors.green.withOpacity(0.9)
            : Colors.cyan.withOpacity(0.8),
        size: 50,
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────
  // Mode Indicator
  // ──────────────────────────────────────────────────────────────

  Widget _buildModeIndicator() {
    final isWorldMode = state.isWorldMode;

    return Positioned(
      bottom: 150,
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
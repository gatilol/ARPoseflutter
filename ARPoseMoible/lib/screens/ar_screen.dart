import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';

import '../config/app_config.dart';
import '../models/ar_state.dart';
import '../models/ar_mode.dart';
import '../models/face_filter_type.dart';
import '../models/model_3d.dart';
import '../models/augmented_image.dart';
import '../services/ar_service.dart';
import '../services/photo_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/ar_overlays.dart';
import '../widgets/model_selector_menu.dart';

/// Main AR screen with World AR and Face AR modes
class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with SingleTickerProviderStateMixin {
  late final ARState arState;
  late ARService arService;
  late final PhotoService photoService;
  final ScreenshotController screenshotController = ScreenshotController();

  // Model menu state
  bool isModelMenuOpen = false;

  // World AR model paths
  String currentWorldModelPath = kDefaultWorldModelPath;

  // Face AR filter paths
  String currentFaceModelPath = '';
  String currentMakeupPath = '';

  // Camera switch animation
  bool _isSwitchingCamera = false;
  late AnimationController _switchAnimationController;
  late Animation<double> _switchAnimation;

  // Augmented Image state
  bool _isAugmentedImageDetected = false;
  bool _isAugmentedImage3DActive = false;
  String? _detectedImageName;

  @override
  void initState() {
    super.initState();

    arState = ARState();
    arService = ARService(
      state: arState,
      modelPath: currentWorldModelPath,
      reticlePath: kReticlePath,
    );
    photoService = PhotoService(state: arState);

    // Camera switch animation setup
    _switchAnimationController = AnimationController(
      duration: kCameraSwitchDuration,
      vsync: this,
    );
    _switchAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _switchAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _switchAnimationController.dispose();
    arService.dispose();
    super.dispose();
  }


  // ──────────────────────────────────────────────────────────────
  // Model Selection
  // ──────────────────────────────────────────────────────────────

  /// Handle model selection from the menu
  void _onModelSelected(Model3D model) {
    HapticFeedback.lightImpact();

    if (arState.isWorldMode) {
      // World AR: Update 3D model
      setState(() {
        currentWorldModelPath = model.path;
      });
      arService.updateModelPath(currentWorldModelPath);

      SnackBarHelper.show(
        context,
        message: 'Model "${model.name}" selected',
        icon: Icons.view_in_ar,
        color: Colors.blue,
      );
    } else {
      // Face AR: Apply face filter
      _applyFaceFilter(model);
    }
  }

  /// Apply a face filter based on its type
  Future<void> _applyFaceFilter(Model3D model) async {
    try {
      switch (model.filterType) {
        case FaceFilterType.none:
          await _clearAllFaceFilters();
          if (!mounted) return;
          SnackBarHelper.show(
            context,
            message: 'All filters removed',
            icon: Icons.face,
            color: Colors.grey,
          );
          break;

        case FaceFilterType.model3D:
          final success = await arService.setFaceModel(model.path);
          if (!mounted) return;
          if (success) {
            setState(() {
              currentFaceModelPath = model.path;
            });
          }
          SnackBarHelper.show(
            context,
            message: success ? 'Model "${model.name}" applied' : 'Error applying model',
            icon: success ? Icons.view_in_ar : Icons.error_outline,
            color: success ? Colors.purple : Colors.red,
          );
          break;

        case FaceFilterType.makeup:
          final success = await arService.sessionManager
              .setFaceMakeupTexture(model.path);
          if (!mounted) return;
          if (success) {
            setState(() {
              currentMakeupPath = model.path;
            });
          }
          SnackBarHelper.show(
            context,
            message: success ? 'Makeup "${model.name}" applied' : 'Error applying makeup',
            icon: success ? Icons.brush : Icons.error_outline,
            color: success ? Colors.pink : Colors.red,
          );
          break;
      }
    } catch (e) {
      debugPrint('Error applying face filter: $e');
      if (!mounted) return;
      SnackBarHelper.showError(context, message: 'Error: $e');
    }
  }

  /// Clear all face filters (3D model + makeup)
  Future<void> _clearAllFaceFilters() async {
    await arService.clearFaceModel();
    await arService.sessionManager.clearFaceMakeupTexture();
    setState(() {
      currentFaceModelPath = '';
      currentMakeupPath = '';
    });
  }

  /// Remove a specific filter type (called from menu's remove button)
  Future<void> _onFilterRemoved(FaceFilterType filterType) async {
    try {
      switch (filterType) {
        case FaceFilterType.model3D:
          await arService.clearFaceModel();
          if (!mounted) return;
          setState(() {
            currentFaceModelPath = '';
          });
          SnackBarHelper.show(
            context,
            message: '3D accessory removed',
            icon: Icons.view_in_ar,
            color: Colors.grey,
          );
          break;

        case FaceFilterType.makeup:
          await arService.sessionManager.clearFaceMakeupTexture();
          if (!mounted) return;
          setState(() {
            currentMakeupPath = '';
          });
          SnackBarHelper.show(
            context,
            message: 'Makeup removed',
            icon: Icons.brush,
            color: Colors.grey,
          );
          break;

        case FaceFilterType.none:
          break;
      }
    } catch (e) {
      debugPrint('Error removing filter: $e');
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Camera Mode Switching
  // ──────────────────────────────────────────────────────────────

  /// Toggle between World AR and Face AR modes
  Future<void> _toggleCameraMode() async {
    if (_isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    await _switchAnimationController.forward();
    HapticFeedback.mediumImpact();

    try {
      final success = await arService.toggleMode();

      if (success && mounted) {
        final newMode = arService.currentMode;

        if (newMode == ArMode.face) {
          // Switched to Face AR: Reset augmented image state
          _isAugmentedImageDetected = false;
          _isAugmentedImage3DActive = false;
          _detectedImageName = null;

          // Reapply face filters if previously set
          if (currentFaceModelPath.isNotEmpty) {
            await arService.setFaceModel(currentFaceModelPath);
          }
          if (currentMakeupPath.isNotEmpty) {
            await arService.sessionManager.setFaceMakeupTexture(currentMakeupPath);
          }
        } else {
          // Switched to World AR: Setup augmented images
          _setupAugmentedImages();
        }

        if (!mounted) return;
        SnackBarHelper.show(
          context,
          message: newMode == ArMode.face ? 'Face AR mode activated' : 'World AR mode activated',
          icon: newMode == ArMode.face ? Icons.face : Icons.view_in_ar,
          color: newMode == ArMode.face ? Colors.purple : Colors.blue,
        );
      } else if (mounted) {
        SnackBarHelper.show(
          context,
          message: 'Face AR not available on this device',
          icon: Icons.info_outline,
          color: Colors.orange,
        );
      }
    } catch (e) {
      debugPrint('Error toggling camera mode: $e');
      if (mounted) {
        SnackBarHelper.showError(context, message: 'Error: $e');
      }
    } finally {
      await _switchAnimationController.reverse();
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Augmented Image 3D
  // ──────────────────────────────────────────────────────────────

  /// Setup augmented image detection
  Future<void> _setupAugmentedImages() async {
    // Skip if feature is disabled
    if (!kEnableAugmentedImages) return;

    // Wait for session manager to be ready
    await Future.delayed(kAugmentedImageSetupDelay);

    final sessionManager = arService.sessionManager;

    // Load augmented images configuration
    final imageConfigs = augmentedImages.map((img) => img.toMap()).toList();
    final result = await sessionManager.loadAugmentedImages(imageConfigs);

    if (result == null || result['success'] != true) {
      debugPrint('Failed to load augmented images');
    }

    // Setup detection callback
    sessionManager.onAugmentedImageDetected = (imageName, detected) {
      if (mounted) {
        setState(() {
          _isAugmentedImageDetected = detected;
          _detectedImageName = detected ? imageName : null;

          // Disable 3D effect if image is lost
          if (!detected && _isAugmentedImage3DActive) {
            _isAugmentedImage3DActive = false;
          }
        });

        if (detected) {
          SnackBarHelper.show(
            context,
            message: 'Image "$imageName" detected!',
            icon: Icons.image_search,
            color: Colors.cyan,
          );
        }
      }
    };
  }

  /// Toggle 3D model on detected augmented image
  Future<void> _toggleAugmentedImage3D() async {
    if (_detectedImageName == null) return;

    final sessionManager = arService.sessionManager;
    HapticFeedback.mediumImpact();

    if (_isAugmentedImage3DActive) {
      // Disable 3D effect
      final success = await sessionManager.disableAugmentedImage3D();
      if (success && mounted) {
        setState(() {
          _isAugmentedImage3DActive = false;
        });
        SnackBarHelper.show(
          context,
          message: '3D model disabled',
          icon: Icons.view_in_ar_outlined,
          color: Colors.grey,
        );
      }
    } else {
      // Enable 3D effect
      final success = await sessionManager.enableAugmentedImage3D(_detectedImageName!);
      if (success && mounted) {
        setState(() {
          _isAugmentedImage3DActive = true;
        });
        SnackBarHelper.showSuccess(
          context,
          message: '3D model activated!',
          icon: Icons.view_in_ar,
        );
      } else if (mounted) {
        SnackBarHelper.showError(
          context,
          message: 'Error activating 3D model',
        );
      }
    }
  }


  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: arState,
        builder: (context, _) {
          return Screenshot(
            controller: screenshotController,
            child: Stack(
              children: [
                // AR View
                ARView(
                  onARViewCreated: (sessionManager, objectManager, anchorManager, locationManager) {
                    arService.onARViewCreated(sessionManager, objectManager, anchorManager);
                    _setupAugmentedImages();
                  },
                  planeDetectionConfig: arState.isWorldMode
                      ? PlaneDetectionConfig.horizontal
                      : PlaneDetectionConfig.none,
                ),

                // Camera switch transition overlay
                if (_isSwitchingCamera)
                  AnimatedBuilder(
                    animation: _switchAnimation,
                    builder: (context, child) {
                      return Container(
                        color: Colors.black.withValues(alpha: _switchAnimation.value * 0.8),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                'Switching camera...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: _switchAnimation.value),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // AR Overlays
                if (!_isSwitchingCamera)
                  AROverlays(
                    state: arState,
                    onClose: () => Navigator.pop(context),
                    onTakePhoto: () async {
                      try {
                        await photoService.takeAndSavePhoto(screenshotController, context);
                      } catch (e) {
                        SnackBarHelper.showError(context, message: 'Error: $e');
                      }
                    },
                    onDelete: () async {
                      if (arState.isWorldMode) {
                        await arService.removeAllModels();
                      } else {
                        await _clearAllFaceFilters();
                      }
                    },
                    onPlaceModel: () async {
                      if (arState.isWorldMode) {
                        await arService.placeModelAtReticle();
                        HapticFeedback.mediumImpact();
                      }
                    },
                    onOpenModelMenu: () {
                      setState(() {
                        isModelMenuOpen = true;
                      });
                    },
                    onRotateReticle: (angle) async {
                      if (arState.isWorldMode) {
                        await arService.rotateReticle(angle);
                      }
                    },
                    onSwitchCamera: _toggleCameraMode,
                    isSwitchingCamera: _isSwitchingCamera,
                    isAugmentedImageDetected: _isAugmentedImageDetected,
                    isAugmentedImage3DActive: _isAugmentedImage3DActive,
                    onToggleAugmentedImage3D: _toggleAugmentedImage3D,
                  ),

                // Model selector menu
                ModelSelectorMenu(
                  isOpen: isModelMenuOpen,
                  onClose: () {
                    setState(() {
                      isModelMenuOpen = false;
                    });
                  },
                  onModelSelected: _onModelSelected,
                  onFilterRemoved: _onFilterRemoved,
                  currentModelPath: arState.isWorldMode
                      ? currentWorldModelPath
                      : currentFaceModelPath,
                  currentMakeupPath: currentMakeupPath,
                  isWorldMode: arState.isWorldMode,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
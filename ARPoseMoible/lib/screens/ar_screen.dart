import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter/services.dart';
import '../models/ar_state.dart';
import '../models/ar_mode.dart';
import '../services/ar_service.dart';
import '../services/photo_service.dart';
import '../widgets/ar_overlays.dart';
import '../widgets/model_selector_menu.dart'; 
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';

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

  // État du menu et modèles sélectionnés
  bool isModelMenuOpen = false;
  
  // ========== World AR Model ==========
  String currentWorldModelPath = 'assets/models/world/eva_01_esg.glb';
  final String reticlePath = 'assets/models/test_reticle.glb';
  
  // ========== Face AR Filter ==========
  String currentFaceModelPath = '';      // Modèle 3D (lunettes, masques...)
  String currentMakeupPath = '';         // Texture makeup (freckles, etc...)

  // ========== FACE AR STATE ==========
  bool _isSwitchingCamera = false;
  late AnimationController _switchAnimationController;
  late Animation<double> _switchAnimation;
  // ====================================

  @override
  void initState() {
    super.initState();
    arState = ARState();
    arService = ARService(
        state: arState,
        modelPath: currentWorldModelPath,
        reticlePath: reticlePath
    );
    photoService = PhotoService(state: arState);

    // Animation pour le switch de caméra
    _switchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _switchAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _switchAnimationController, curve: Curves.easeInOut),
    );
  }

  // ==================================================================================
  // ========================= SÉLECTION DE MODÈLE ====================================
  // ==================================================================================

  /// Méthode appelée quand un modèle est sélectionné (World AR ou Face AR)
  void _onModelSelected(Model3D model) {
    HapticFeedback.lightImpact();

    if (arState.isWorldMode) {
      // ========== World AR : Mise à jour du modèle 3D ==========
      setState(() {
        currentWorldModelPath = model.path;
      });
      arService.updateModelPath(currentWorldModelPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.view_in_ar, color: Colors.white),
                const SizedBox(width: 12),
                Text('Modèle "${model.name}" sélectionné'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } else {
      // ========== Face AR : Appliquer le filtre facial ==========
      // _applyFaceFilter met à jour les bonnes variables selon le type
      _applyFaceFilter(model);
    }
  }

  /// Applique un filtre facial selon son type (none, model3D, makeup)
  /// Les modèles 3D et les maquillages peuvent être combinés
  Future<void> _applyFaceFilter(Model3D model) async {
    try {
      switch (model.filterType) {
        case FaceFilterType.none:
          // Supprimer tous les filtres
          await _clearAllFaceFilters();
          _showFilterSnackBar('Tous les filtres supprimés', Icons.face, Colors.grey);
          break;
          
        case FaceFilterType.model3D:
          // Appliquer le modèle 3D (sans toucher au makeup)
          final success = await arService.setFaceModel(model.path);
          if (success) {
            setState(() {
              currentFaceModelPath = model.path;
            });
          }
          _showFilterSnackBar(
            success ? 'Modèle "${model.name}" appliqué' : 'Erreur lors de l\'application',
            success ? Icons.view_in_ar : Icons.error_outline,
            success ? Colors.purple : Colors.red,
          );
          break;
          
        case FaceFilterType.makeup:
          // Appliquer la texture makeup (sans toucher au modèle 3D)
          final success = await arService.sessionManager?.setFaceMakeupTexture(model.path) ?? false;
          if (success) {
            setState(() {
              currentMakeupPath = model.path;
            });
          }
          _showFilterSnackBar(
            success ? 'Maquillage "${model.name}" appliqué' : 'Erreur lors de l\'application',
            success ? Icons.brush : Icons.error_outline,
            success ? Colors.pink : Colors.red,
          );
          break;
      }
    } catch (e) {
      debugPrint('Error applying face filter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Supprime tous les filtres faciaux (modèle 3D + texture)
  Future<void> _clearAllFaceFilters() async {
    await arService.clearFaceModel();
    await arService.sessionManager?.clearFaceMakeupTexture();
    setState(() {
      currentFaceModelPath = '';
      currentMakeupPath = '';
    });
  }

  /// Supprime un type de filtre spécifique (appelé depuis le bouton ❌ du menu)
  Future<void> _onFilterRemoved(FaceFilterType filterType) async {
    try {
      switch (filterType) {
        case FaceFilterType.model3D:
          await arService.clearFaceModel();
          setState(() {
            currentFaceModelPath = '';
          });
          _showFilterSnackBar('Accessoire 3D supprimé', Icons.view_in_ar, Colors.grey);
          break;
          
        case FaceFilterType.makeup:
          await arService.sessionManager?.clearFaceMakeupTexture();
          setState(() {
            currentMakeupPath = '';
          });
          _showFilterSnackBar('Maquillage supprimé', Icons.brush, Colors.grey);
          break;
          
        case FaceFilterType.none:
          // Rien à faire
          break;
      }
    } catch (e) {
      debugPrint('Error removing filter: $e');
    }
  }

  /// Affiche un SnackBar pour les filtres
  void _showFilterSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: color,
      ),
    );
  }

  // ==================================================================================
  // ========================= MÉTHODES SWITCH CAMÉRA =================================
  // ==================================================================================

  /// Bascule entre les modes World AR et Face AR
  Future<void> _toggleCameraMode() async {
    if (_isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    // Animation de transition
    await _switchAnimationController.forward();

    HapticFeedback.mediumImpact();

    try {
      final success = await arService.toggleMode();

      if (success && mounted) {
        final newMode = arService.currentMode;
        
        // Si on passe en Face AR, réappliquer les filtres sélectionnés
        if (newMode == ArMode.face) {
          // Réappliquer le modèle 3D si présent
          if (currentFaceModelPath.isNotEmpty) {
            await arService.setFaceModel(currentFaceModelPath);
          }
          // Réappliquer le makeup si présent
          if (currentMakeupPath.isNotEmpty) {
            await arService.sessionManager?.setFaceMakeupTexture(currentMakeupPath);
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newMode == ArMode.face ? Icons.face : Icons.view_in_ar,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  newMode == ArMode.face 
                    ? 'Mode Face AR activé' 
                    : 'Mode World AR activé',
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newMode == ArMode.face ? Colors.purple : Colors.blue,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Face AR non disponible sur cet appareil',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling camera mode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  // ==================================================================================
  // ========================= BUILD =================================================
  // ==================================================================================

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
                // Vue AR
                ARView(
                  onARViewCreated: (sessionManager, objectManager, anchorManager, locationManager) {
                    arService.onARViewCreated(sessionManager, objectManager, anchorManager);
                  },
                  planeDetectionConfig: arState.isWorldMode 
                    ? PlaneDetectionConfig.horizontal 
                    : PlaneDetectionConfig.none,
                ),

                // Overlay de transition lors du switch
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
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Changement de caméra...',
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

                // Overlays AR
                if (!_isSwitchingCamera)
                  AROverlays(
                    state: arState,
                    onClose: () => Navigator.pop(context),
                    onTakePhoto: () async {
                      try {
                        await photoService.takeAndSavePhoto(screenshotController, context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red
                            )
                          );
                        }
                      }
                    },
                    onDelete: () async {
                      if (arState.isWorldMode) {
                        await arService.removeAllModels();
                      } else {
                        // En mode Face AR, supprimer tous les filtres
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
                  ),

                // Menu de sélection des modèles
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

  @override
  void dispose() {
    _switchAnimationController.dispose();
    arService.dispose();
    super.dispose();
  }
}
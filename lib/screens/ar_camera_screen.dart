import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';

import '../constants/app_constants.dart';
import '../models/ar_object_config.dart';
import '../services/camera_service.dart';
import '../services/photo_service.dart';
import '../widgets/ar_object_viewer.dart';
import '../widgets/camera_controls.dart';
import '../widgets/overlay_gradient.dart';

/// Écran principal de la caméra AR
class ARCameraScreen extends StatefulWidget {
  final Function(String photoPath)? onPhotoTaken;
  final VoidCallback? onClose;
  final ARObjectConfig? objectConfig;
  
  const ARCameraScreen({
    Key? key,
    this.onPhotoTaken,
    this.onClose,
    this.objectConfig,
  }) : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  // Services
  final CameraService _cameraService = CameraService();
  final PhotoService _photoService = PhotoService();
  final ScreenshotController _screenshotController = ScreenshotController();
  
  // État
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isCapturingPhoto = false;
  
  // Configuration de l'objet AR
  late ARObjectConfig _objectConfig;

  @override
  void initState() {
    super.initState();
    _objectConfig = widget.objectConfig ?? ARObjectConfig.defaultModel();
    _initializeCamera();
  }

  /// Initialiser la caméra
  Future<void> _initializeCamera() async {
    try {
      // Obtenir les caméras disponibles
      final cameras = await availableCameras();
      await _cameraService.initialize(cameras);
      
      // Vérifier les permissions
      final hasPermission = await _cameraService.checkPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = AppConstants.cameraPermissionDenied;
          _isLoading = false;
        });
        return;
      }
      
      // Initialiser la première caméra
      await _cameraService.initializeCamera();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Prendre une photo
  Future<void> _takePhoto() async {
    try {
      // Cacher les overlays
      setState(() => _isCapturingPhoto = true);
      await Future.delayed(AppConstants.captureDelay);

      // Lancer la capture en parallèle
      final captureFuture = _screenshotController.capture();
      
      // Attendre que la capture commence vraiment
      await Future.delayed(AppConstants.overlayHideDelay);
      
      // Réafficher les overlays
      setState(() => _isCapturingPhoto = false);
      
      // Attendre le résultat de la capture
      final Uint8List? imageBytes = await captureFuture;
      
      if (imageBytes == null) {
        throw Exception('Impossible de capturer l\'écran');
      }

      // Sauvegarder la photo
      final photoPath = await _photoService.saveToGallery(imageBytes);
      
      // Callback si fourni (pour l'intégration future)
      widget.onPhotoTaken?.call(photoPath);
      
      // Feedback visuel
      HapticFeedback.mediumImpact();
      _showSuccessMessage();
      
    } catch (e) {
      setState(() => _isCapturingPhoto = false);
      _showErrorMessage(e.toString());
    }
  }

  /// Changer de caméra
  Future<void> _switchCamera() async {
    try {
      if (_cameraService.cameraCount < 2) {
        _showInfoMessage(AppConstants.onlyOneCameraAvailable);
        return;
      }
      
      setState(() => _isLoading = true);
      await _cameraService.switchCamera();
      setState(() => _isLoading = false);
      
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage(e.toString());
    }
  }

  /// Fermer l'écran
  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      SystemNavigator.pop();
    }
  }

  /// Afficher un message de succès
  void _showSuccessMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(AppConstants.photoSaved),
          ],
        ),
        backgroundColor: Colors.green,
        duration: AppConstants.snackbarDuration,
      ),
    );
  }

  /// Afficher un message d'erreur
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: AppConstants.snackbarDuration,
      ),
    );
  }

  /// Afficher un message d'information
  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: AppConstants.snackbarDuration,
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Écran d'erreur
    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }

    // Écran principal AR
    return _buildARScreen();
  }

  /// Construire l'écran de chargement
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              AppConstants.initializingCamera,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Construire l'écran d'erreur
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),
                SizedBox(height: 24),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: Icon(Icons.refresh),
                  label: Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construire l'écran AR principal
  Widget _buildARScreen() {
    return Scaffold(
      body: Screenshot(
        controller: _screenshotController,
        child: Stack(
          children: [
            // Vue caméra
            SizedBox.expand(
              child: CameraPreview(_cameraService.controller!),
            ),

            // Modèle 3D GLB
            ARObjectViewer(
              config: _objectConfig,
            ),

            // Overlays (conditionnels pendant la capture)
            if (!_isCapturingPhoto) ...[
              // Gradient du haut
              OverlayGradient(isTop: true),
              
              // Bouton de fermeture
              ARCloseButton(onPressed: _close),
              
              // Instructions
              InstructionText(),
              
              // Gradient du bas
              OverlayGradient(
                isTop: false,
                height: AppConstants.overlayBottomHeight,
              ),
              
              // Contrôles de la caméra
              CameraControls(
                onTakePhoto: _takePhoto,
                onSwitchCamera: _switchCamera,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
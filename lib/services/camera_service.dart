import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service de gestion de la caméra
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  
  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  int get cameraCount => _cameras.length;
  
  /// Initialiser le service avec la liste des caméras disponibles
  Future<void> initialize(List<CameraDescription> cameras) async {
    _cameras = cameras;
    if (_cameras.isEmpty) {
      throw Exception('Aucune caméra disponible');
    }
  }
  
  /// Vérifier et demander la permission caméra
  Future<bool> checkPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  /// Initialiser la caméra à l'index donné
  Future<void> initializeCamera([int index = 0]) async {
    if (_cameras.isEmpty) {
      throw Exception('Aucune caméra disponible');
    }
    
    // Disposer de l'ancienne caméra si elle existe
    if (_controller != null) {
      await _controller!.dispose();
    }
    
    _currentCameraIndex = index % _cameras.length;
    
    _controller = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _controller!.initialize();
  }
  
  /// Changer de caméra (avant/arrière)
  Future<void> switchCamera() async {
    if (_cameras.length < 2) {
      throw Exception('Une seule caméra disponible');
    }
    
    final nextIndex = (_currentCameraIndex + 1) % _cameras.length;
    await initializeCamera(nextIndex);
  }
  
  /// Libérer les ressources
  void dispose() {
    _controller?.dispose();
  }
}
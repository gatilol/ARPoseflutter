import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:math' as math;
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ARCameraScreen(),
    );
  }
}

class ARCameraScreen extends StatefulWidget {
  @override
  _ARCameraScreenState createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? cameraController;
  bool isLoading = true;
  String errorMessage = '';
  int selectedCamera = 0;
  late AnimationController _animController;
  double _rotation = 0.0;
  ScreenshotController screenshotController = ScreenshotController();
  bool isCapturingPhoto = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat();
    
    _animController.addListener(() {
      setState(() {
        _rotation = _animController.value * 2 * math.pi;
      });
    });
    
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    var cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      await _initializeCamera(selectedCamera);
    } else {
      setState(() {
        errorMessage = 'Permission caméra refusée.';
        isLoading = false;
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (cameras.isEmpty) {
      setState(() {
        errorMessage = 'Aucune caméra disponible';
        isLoading = false;
      });
      return;
    }

    if (cameraController != null) {
      await cameraController!.dispose();
    }

    cameraController = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await cameraController!.initialize();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Erreur caméra: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Cacher les overlays
      setState(() {
        isCapturingPhoto = true;
      });

      // Attendre que l'UI se mette à jour
      await Future.delayed(Duration(milliseconds: 50));

      // Capturer l'écran
      final Uint8List? imageBytes = await screenshotController.capture();
      
      // Réafficher les overlays immédiatement
      setState(() {
        isCapturingPhoto = false;
      });
      
      if (imageBytes == null) {
        throw Exception('Impossible de capturer l\'écran');
      }

      // Sauvegarder en arrière-plan pour ne pas bloquer l'UI
      _savePhoto(imageBytes);

      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        isCapturingPhoto = false;
      });
      
      print('Erreur photo: $e');
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

  Future<void> _savePhoto(Uint8List imageBytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(directory.path, 'ar_photo_$timestamp.png');
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      await Gal.putImage(imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Photo AR enregistrée !'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Une seule caméra disponible')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      selectedCamera = (selectedCamera + 1) % cameras.length;
    });

    await _initializeCamera(selectedCamera);

    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    cameraController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Initialisation caméra...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
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
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _checkPermissions(),
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

    return Scaffold(
      body: Screenshot(
        controller: screenshotController,
        child: Stack(
          children: [
            SizedBox.expand(
              child: CameraPreview(cameraController!),
            ),

            Center(
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_rotation)
                  ..rotateY(_rotation * 1.5),
                alignment: FractionalOffset.center,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.7),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!isCapturingPhoto)
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

            if (!isCapturingPhoto)
              Positioned(
                top: 16 + MediaQuery.of(context).padding.top,
                left: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => SystemNavigator.pop(),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),

            if (!isCapturingPhoto)
              Positioned(
                top: 80 + MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    margin: EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Cube 3D AR - Prenez une photo !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            if (!isCapturingPhoto)
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

            if (!isCapturingPhoto)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircleButton(
                        icon: Icons.flip_camera_ios,
                        onPressed: _switchCamera,
                        size: 60,
                      ),
                      _buildCircleButton(
                        icon: Icons.camera_alt,
                        onPressed: _takePhoto,
                        size: 80,
                        isPrimary: true,
                      ),
                      SizedBox(width: 60),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
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
            color: isPrimary ? Colors.white : Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary ? Colors.blue : Colors.white,
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
            color: isPrimary ? Colors.blue : Colors.black87,
            size: isPrimary ? 40 : 28,
          ),
        ),
      ),
    );
  }
}
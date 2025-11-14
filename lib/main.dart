import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/ar_camera_screen.dart';
import 'constants/app_constants.dart';

/// Point d'entrée de l'application standalone
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Forcer le mode portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(ARCameraApp());
}

/// Application AR Camera (mode standalone)
class ARCameraApp extends StatelessWidget {
  const ARCameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: AppConstants.primaryColor,
        brightness: Brightness.light,
      ),
      // Lancer directement l'écran AR
      home: ARCameraScreen(
        // Callbacks optionnels (pour test ou futur usage)
        onPhotoTaken: (String photoPath) {
          print('📸 Photo prise : $photoPath');
          // TODO: Envoyer au backend Laravel, etc.
        },
        onClose: () {
          // En mode standalone, fermer l'app
          SystemNavigator.pop();
        },
      ),
    );
  }
}

/* 
════════════════════════════════════════════════════════════════════════════════
💡 INTÉGRATION FUTURE DANS UNE AUTRE APP :

Dans votre app principale (par exemple l'app Laravel/Flutter), vous pourrez faire :

```dart
import 'package:flu_ar_simple/screens/ar_camera_screen.dart';
import 'package:flu_ar_simple/models/ar_object_config.dart';

// Dans un bouton ou menu de votre app principale :
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ARCameraScreen(
      onPhotoTaken: (String photoPath) {
        // Faire quelque chose avec la photo
        _sendToBackend(photoPath);
      },
      onClose: () {
        Navigator.pop(context);
      },
      objectConfig: ARObjectConfig.defaultCube(), // ou .fromGLB(...)
    ),
  ),
);
```

Le code est 100% modulaire et prêt à être intégré ! 🎯
════════════════════════════════════════════════════════════════════════════════
*/
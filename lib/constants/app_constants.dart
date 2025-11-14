import 'package:flutter/material.dart';

/// Constantes de l'application
class AppConstants {
  // Couleurs
  static const MaterialColor primaryColor = Colors.blue;
  static const Color accentColor = Colors.white;
  
  // Tailles
  static const double buttonSizeLarge = 80.0;
  static const double buttonSizeSmall = 60.0;
  static const double overlayHeight = 120.0;
  static const double overlayBottomHeight = 180.0;
  
  // Durées et animations
  static const Duration captureDelay = Duration(milliseconds: 10);
  static const Duration overlayHideDelay = Duration(milliseconds: 200);
  static const Duration snackbarDuration = Duration(seconds: 2);
  
  // Textes
  static const String appTitle = 'AR Camera';
  static const String cameraPermissionDenied = 'Permission caméra refusée.';
  static const String noCameraAvailable = 'Aucune caméra disponible';
  static const String initializingCamera = 'Initialisation caméra...';
  static const String instructionText = 'Modèle 3D AR - Prenez une photo !';
  static const String photoSaved = 'Photo AR enregistrée !';
  static const String photoError = 'Erreur lors de la prise de photo';
  static const String onlyOneCameraAvailable = 'Une seule caméra disponible';
}
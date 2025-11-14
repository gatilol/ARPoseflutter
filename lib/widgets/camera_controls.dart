import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Contrôles de la caméra (boutons photo et switch)
class CameraControls extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onSwitchCamera;
  
  const CameraControls({
    Key? key,
    required this.onTakePhoto,
    required this.onSwitchCamera,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bouton switch caméra
            _CircleButton(
              icon: Icons.flip_camera_ios,
              onPressed: onSwitchCamera,
              size: AppConstants.buttonSizeSmall,
            ),
            
            // Bouton photo (plus grand)
            _CircleButton(
              icon: Icons.camera_alt,
              onPressed: onTakePhoto,
              size: AppConstants.buttonSizeLarge,
              isPrimary: true,
            ),
            
            // Espace pour symétrie
            SizedBox(width: AppConstants.buttonSizeSmall),
          ],
        ),
      ),
    );
  }
}

/// Bouton circulaire personnalisé
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isPrimary;
  
  const _CircleButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    required this.size,
    this.isPrimary = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isPrimary 
                ? AppConstants.accentColor 
                : AppConstants.accentColor.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary 
                  ? AppConstants.primaryColor 
                  : AppConstants.accentColor,
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
            color: isPrimary 
                ? AppConstants.primaryColor 
                : Colors.black87,
            size: isPrimary ? 40 : 28,
          ),
        ),
      ),
    );
  }
}
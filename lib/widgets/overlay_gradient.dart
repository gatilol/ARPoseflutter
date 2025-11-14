import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Overlay avec dégradé (haut ou bas de l'écran)
class OverlayGradient extends StatelessWidget {
  final bool isTop;
  final double height;
  
  const OverlayGradient({
    Key? key,
    this.isTop = true,
    this.height = AppConstants.overlayHeight,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0,
      right: 0,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(isTop ? 0.6 : 0.7),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton de fermeture circulaire
class ARCloseButton extends StatelessWidget {  // ← Renommé
  final VoidCallback onPressed;
  
  const ARCloseButton({  // ← Renommé
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16 + MediaQuery.of(context).padding.top,
      left: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
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
    );
  }
}

/// Texte d'instructions
class InstructionText extends StatelessWidget {
  final String text;
  
  const InstructionText({
    Key? key,
    this.text = AppConstants.instructionText,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
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
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
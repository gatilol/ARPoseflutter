import 'package:flutter/material.dart';
import '../models/ar_state.dart';
import 'circle_button.dart';

class AROverlays extends StatelessWidget {
  final ARState state;
  final VoidCallback onClose;
  final VoidCallback onTakePhoto;
  final VoidCallback onDelete;

  const AROverlays({
    required this.state,
    required this.onClose,
    required this.onTakePhoto,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isCapturing) return const SizedBox.shrink();

    return Stack(
      children: [
        // top gradient
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 120, decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Colors.black.withOpacity(0.6), Colors.transparent
            ])
        ))),
        // close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(25),
              child: Container(width:50,height:50,decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),shape: BoxShape.circle),child: const Icon(Icons.close, color: Colors.white)),
            ),
          ),
        ),
        // instructions
        if (!state.hasPlacedModel)
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            left: 0, right: 0, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3)),),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app, color: Colors.white, size: 32), SizedBox(height:8), Text('Touchez une surface pour\nplacer le modèle 3D', textAlign: TextAlign.center, style: TextStyle(color: Colors.white,fontSize:14,fontWeight: FontWeight.bold))]),
          )),
          ),
        // bottom gradient
        Positioned(bottom: 0,left:0,right:0,child: Container(height:180,decoration:BoxDecoration(gradient: LinearGradient(begin:Alignment.bottomCenter,end:Alignment.topCenter,colors:[Colors.black.withOpacity(0.7),Colors.transparent])))),
        // photo button
        Positioned(bottom: 50,left:0,right:0,child: Center(child: CircleButton(icon: Icons.camera_alt, onPressed: onTakePhoto, size:80, isPrimary: true))),
        // delete button
        Positioned(bottom: 50,right:20,child: FloatingActionButton(heroTag:'delete', onPressed: onDelete, backgroundColor: Colors.red, child: const Icon(Icons.delete))),
      ],
    );
  }
}

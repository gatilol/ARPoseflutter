import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isPrimary;
  final Color? color;

  const CircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.isPrimary = false,
    this.color,
    super.key,
  });

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
            color: isPrimary ? Colors.white : (color ?? Colors.white).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary ? Colors.blue : (color ?? Colors.white),
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
          child: Icon(icon, color: isPrimary ? Colors.blue : (color ?? Colors.black87),
              size: isPrimary ? 40 : 28),
        ),
      ),
    );
  }
}

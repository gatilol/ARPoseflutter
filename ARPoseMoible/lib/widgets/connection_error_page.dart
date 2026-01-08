import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConnectionErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ConnectionErrorPage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B2BFF), // rgba(123, 43, 255, 1)
            Color(0xFFFF87DF), // rgba(255, 135, 223, 1)
          ],
          stops: [0.3, 0.8],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hexagone avec icône
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: CustomPaint(
                      size: Size(120, 120),
                      painter: HexagonPainter(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(
                          child: Icon(
                            Icons.wifi_off,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Titre
              Text(
                'Pas de connexion',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Bouton hexagonal allongé
              GestureDetector(
                onTap: onRetry,
                child: CustomPaint(
                  size: Size(220, 70),
                  painter: ElongatedHexagonPainter(
                    color: Colors.green,
                  ),
                  child: Container(
                    width: 220,
                    height: 70,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Réessayer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.refresh,
                          color: Color(0xFFFFFFFF),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter pour dessiner un hexagone standard (flat top)
class HexagonPainter extends CustomPainter {
  final Color color;

  HexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);

    // Bordure blanche
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(HexagonPainter oldDelegate) => oldDelegate.color != color;
}

/// Painter pour dessiner un hexagone allongé (bouton)
class ElongatedHexagonPainter extends CustomPainter {
  final Color color;

  ElongatedHexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Calculer les dimensions
    final height = size.height;
    final width = size.width;
    final cornerWidth = height * 0.3; // Largeur des coins inclinés

    // Dessiner l'hexagone allongé (octogone arrondi)
    // Coin supérieur gauche
    path.moveTo(cornerWidth, 0);

    // Ligne supérieure
    path.lineTo(width - cornerWidth, 0);

    // Coin supérieur droit
    path.lineTo(width, height / 2);

    // Coin inférieur droit
    path.lineTo(width - cornerWidth, height);

    // Ligne inférieure
    path.lineTo(cornerWidth, height);

    // Coin inférieur gauche
    path.lineTo(0, height / 2);

    path.close();

    // Ombre portée
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 8, true);

    // Remplissage
    canvas.drawPath(path, paint);

    // Bordure
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(ElongatedHexagonPainter oldDelegate) =>
      oldDelegate.color != color;
}
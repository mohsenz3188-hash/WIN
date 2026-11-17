import 'dart:math' as math;
import 'package:flutter/material.dart';

class DragonColors {
  static const Color oledBlack = Color(0xFF05060A);
  static const Color charcoal = Color(0xFF0C1018);
  static const Color cardSurface = Color(0xFF121826);
  static const Color electricBlue = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color crimsonRed = Color(0xFFFF1744);
  static const Color emberOrange = Color(0xFFFF6D00);
  static const Color textPrimary = Color(0xFFF3F6FC);
  static const Color textSecondary = Color(0xFF8B9BB4);
}

ThemeData buildDragonTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: DragonColors.oledBlack,
    colorScheme: const ColorScheme.dark(
      primary: DragonColors.electricBlue,
      secondary: DragonColors.crimsonRed,
      surface: DragonColors.charcoal,
      error: DragonColors.crimsonRed,
    ),
    cardTheme: CardTheme(
      color: DragonColors.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: DragonColors.electricBlue.withOpacity(0.18),
          width: 1,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

class DragonScalePainter extends CustomPainter {
  final Color accentColor;
  DragonScalePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double radius = 26;
    const double dx = radius * 1.5;
    final double dy = radius * math.sqrt(3);

    for (double y = -dy; y < size.height + dy; y += dy / 2) {
      final int row = (y / (dy / 2)).round();
      final double xOffset = row.isOdd ? dx : 0;
      for (double x = -dx; x < size.width + dx; x += dx * 2) {
        final center = Offset(x + xOffset, y);
        final path = Path()
          ..addArc(
            Rect.fromCircle(center: center, radius: radius),
            0.12 * math.pi,
            0.76 * math.pi,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DragonScalePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

class DragonLogoPainter extends CustomPainter {
  final Color primary;
  final Color secondary;

  DragonLogoPainter({
    this.primary = DragonColors.electricBlue,
    this.secondary = DragonColors.crimsonRed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final crestPaint = Paint()
      ..shader = LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeJoin = StrokeJoin.round;

    final shieldPath = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.72, h * 0.18)
      ..lineTo(w * 0.94, h * 0.12)
      ..lineTo(w * 0.84, h * 0.48)
      ..lineTo(w * 0.68, h * 0.84)
      ..lineTo(w * 0.50, h * 0.96)
      ..lineTo(w * 0.32, h * 0.84)
      ..lineTo(w * 0.16, h * 0.48)
      ..lineTo(w * 0.06, h * 0.12)
      ..lineTo(w * 0.28, h * 0.18)
      ..close();
    canvas.drawPath(shieldPath, crestPaint);

    final eyePaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.fill;
    final eyePath = Path()
      ..moveTo(w * 0.26, h * 0.45)
      ..lineTo(w * 0.50, h * 0.33)
      ..lineTo(w * 0.74, h * 0.45)
      ..lineTo(w * 0.50, h * 0.67)
      ..close();
    canvas.drawPath(eyePath, eyePaint);
  }

  @override
  bool shouldRepaint(covariant DragonLogoPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}

class DragonWingAuraPainter extends CustomPainter {
  final Color color;
  final double pulse;

  DragonWingAuraPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.28 + pulse * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int side in [-1, 1]) {
      for (int i = 0; i < 3; i++) {
        final wing = Path()
          ..moveTo(cx + side * (72 + i * 8), cy - 18 + i * 12)
          ..quadraticBezierTo(
            cx + side * (112 + i * 10 + pulse * 6),
            cy - 44 + i * 16,
            cx + side * (94 + i * 6),
            cy + 22 + i * 12,
          );
        canvas.drawPath(wing, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DragonWingAuraPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pulse != pulse;
}

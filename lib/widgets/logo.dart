import 'package:flutter/material.dart';

import '../core/palette.dart';

/// The Interface Browser mark: a navy rounded square with a cyan globe.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF102A5C), BrowserPalette.navyDeep],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: CustomPaint(
        painter: _GlobePainter(
          stroke: const Color(0xFF35E4FF),
          strokeWidth: size * 0.055,
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({required this.stroke, required this.strokeWidth});

  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;

    // Outer circle.
    canvas.drawCircle(c, r, paint);
    // Meridian ellipses.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2 * 0.45, height: r * 2),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2 * 0.8, height: r * 2),
      paint,
    );
    // Equator.
    canvas.drawLine(
      Offset(c.dx - r, c.dy),
      Offset(c.dx + r, c.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      old.stroke != stroke || old.strokeWidth != strokeWidth;
}

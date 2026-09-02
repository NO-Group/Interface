import 'package:flutter/material.dart';


/// The Interface Browser mark, shown exactly as supplied: the brand artwork at
/// its own aspect ratio, on no background. A painted cyan globe is used only
/// when the asset cannot be read (e.g. unit tests without an asset bundle).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _GlobeTile(size: size),
    );
  }
}

class _GlobeTile extends StatelessWidget {
  const _GlobeTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlobePainter(
          stroke: Theme.of(context).colorScheme.primary,
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

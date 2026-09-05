import 'dart:ui';

import 'package:flutter/material.dart';

/// Blurred container for the chrome, used only by the wallpaper theme.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.enabled,
    required this.color,
    this.child,
    this.padding,
    this.border,
    this.radius,
  });

  final bool enabled;
  final Color color;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? BorderRadius.zero;
    if (!enabled) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: border,
          borderRadius: r,
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            border: border,
            borderRadius: r,
          ),
          child: child,
        ),
      ),
    );
  }
}

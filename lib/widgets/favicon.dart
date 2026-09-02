import 'package:flutter/material.dart';

import '../core/pal.dart';
import '../core/urls.dart';

/// A favicon with graceful fallback: real favicon → Google s2 → letter tile.
class Favicon extends StatelessWidget {
  const Favicon({super.key, required this.host, this.url, this.size = 18});

  final String host;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final letter = host.isEmpty ? '?' : host[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w700,
          color: palette.accent,
        ),
      ),
    );

    final src = (url != null && url!.isNotEmpty)
        ? url
        : (host.isEmpty ? null : faviconUrlForHost(host, size: 64));
    if (src == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

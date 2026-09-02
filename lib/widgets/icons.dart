import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Interface's own icon set: 24x24 line icons drawn as SVG and shipped in
/// `assets/icons/`. Every glyph is recoloured to the surrounding text colour,
/// so icons follow the theme (including the pure black & white one).
///
/// Reference by name: `Ico('close')`, or pass the name to `UiIconButton` /
/// `UiButton`, which accept either an icon name or any widget.
class Ico extends StatelessWidget {
  const Ico(this.name, {super.key, this.size = 20, this.color, this.opacity});

  /// Icon name without the `.svg` extension, e.g. `reload`.
  final String name;
  final double size;

  /// Paint colour; defaults to the ambient icon colour.
  final Color? color;
  final double? opacity;

  static const String dir = 'assets/icons/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.iconTheme.color ?? theme.colorScheme.onSurface;
    final c = opacity == null ? base : base.withValues(alpha: opacity);
    return SvgPicture.asset(
      '$dir$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

/// Turns an icon spec (an [Ico] name, any widget, or a font glyph) into a
/// widget, so both icon styles keep working everywhere.
Widget uiGlyph(Object? spec, {double size = 20, Color? color, double? opacity}) {
  if (spec is String) return Ico(spec, size: size, color: color, opacity: opacity);
  if (spec is Widget) return spec;
  if (spec is IconData) {
    return Icon(spec,
        size: size,
        color: opacity == null ? color : color?.withValues(alpha: opacity));
  }
  return const SizedBox.shrink();
}

/// The file manager's per-kind icons. Unknown names fall back to a page.
String fileIconName(String name, {required bool isDir}) {
  String ext(String n) {
    final dot = n.lastIndexOf('.');
    return dot <= 0 || dot == n.length - 1 ? '' : n.substring(dot + 1).toLowerCase();
  }

  if (isDir) return 'folder';
  switch (ext(name)) {
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'heic':
    case 'svg':
      return 'image';
    case 'mp4':
    case 'mkv':
    case 'mov':
    case 'avi':
    case 'webm':
      return 'video';
    case 'mp3':
    case 'm4a':
    case 'flac':
    case 'wav':
    case 'ogg':
      return 'music';
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return 'archive';
    case 'pdf':
      return 'file-pdf';
    case 'dart':
    case 'js':
    case 'ts':
    case 'py':
    case 'java':
    case 'kt':
    case 'c':
    case 'h':
    case 'cpp':
    case 'cs':
    case 'go':
    case 'rs':
    case 'php':
    case 'rb':
    case 'swift':
    case 'json':
    case 'yaml':
    case 'yml':
    case 'xml':
    case 'html':
    case 'css':
    case 'sh':
    case 'bat':
      return 'file-code';
    case 'txt':
    case 'md':
    case 'rtf':
    case 'log':
    case 'csv':
    case 'doc':
    case 'docx':
    case 'xls':
    case 'xlsx':
    case 'ppt':
    case 'pptx':
      return 'file-text';
    default:
      return 'file';
  }
}

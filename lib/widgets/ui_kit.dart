import 'dart:async';

import 'package:flutter/material.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';

/// Hover + press state for anything clickable that is not a Material button:
/// tab pills, chips, list rows, menu items.
class UiHoverable extends StatefulWidget {
  const UiHoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
    this.showClickCursor = true,
  });

  final Widget Function(BuildContext context, bool hovering, bool pressed)
      builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool enabled;
  final bool showClickCursor;

  @override
  State<UiHoverable> createState() => _UiHoverableState();
}

class _UiHoverableState extends State<UiHoverable> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.enabled && widget.onTap != null;
    return MouseRegion(
      cursor: clickable && widget.showClickCursor
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enabled ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovering = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: clickable ? widget.onTap : null,
        onTapDown: clickable ? (_) => setState(() => _pressed = true) : null,
        onTapUp: clickable
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: clickable ? () => setState(() => _pressed = false) : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onSecondaryTap: widget.enabled ? widget.onSecondaryTap : null,
        child: Builder(
          builder: (context) =>
              widget.builder(context, _hovering && clickable, _pressed),
        ),
      ),
    );
  }
}

/// A toolbar icon button: fixed square, tinted hover, accent when selected.
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onTap,
    this.selected = false,
    this.color,
    this.iconSize = 18,
    this.size = 34,
    this.badge = 0,
    this.badgeColor,
  });

  final Object icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final double iconSize;
  final double size;
  final int badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final enabled = onTap != null;
    final child = UiHoverable(
      onTap: onTap,
      enabled: enabled,
      builder: (context, hovering, pressed) => AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        decoration: BoxDecoration(
          color: pressed
              ? p.activeFill
              : (hovering
                  ? p.hoverFill
                  : (selected ? p.activeFill : Colors.transparent)),
          borderRadius: Ui.petal(
            Ui.rControl,
            at: selected ? UiCorner.topLeft : UiCorner.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            uiGlyph(
              icon,
              size: iconSize,
              color: !enabled
                  ? p.textFaint
                  : (selected ? p.accent : (color ?? p.text)),
            ),
            // A control that is on has a keel; nothing else in the bar does.
            if (selected)
              Positioned(
                left: 7,
                right: 7,
                bottom: 3,
                child: Ui.keel(p, horizontal: true),
              ),
          ],
        ),
      ),
    );
    final counted = badge > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(
                top: 3,
                right: 3,
                child: UiBadge(
                  count: badge,
                  color: badgeColor ?? p.accent,
                  textColor: badgeColor == null ? p.onAccent : p.surface,
                ),
              ),
            ],
          )
        : child;
    if (tooltip == null) return SizedBox(width: size, height: size, child: counted);
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 450),
      child: SizedBox(width: size, height: size, child: counted),
    );
  }
}

/// Tiny count bubble (blocked trackers, running downloads, unread items).
class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    required this.count,
    this.color,
    this.textColor,
    this.label,
  });

  final int count;
  final Color? color;
  final Color? textColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final text = label ?? (count > 99 ? '99+' : '$count');
    return Container(
      constraints: const BoxConstraints(minWidth: 15, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? p.accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: Ui.text(
          p,
          size: 9.5,
          weight: FontWeight.w700,
          color: textColor ?? p.onAccent,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Back / forward / reload sit in one quiet segment so the bar reads as
/// three groups (nav · tabs · address) instead of fourteen loose icons.
class UiCluster extends StatelessWidget {
  const UiCluster({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// The loading line pinned under the top bar: 2px, accent, no spinner.
class UiProgressLine extends StatefulWidget {
  const UiProgressLine({super.key, required this.active, this.progress = 0});

  final bool active;

  /// 0..100, as the web view reports it. Below 1 means "unknown".
  final num progress;

  @override
  State<UiProgressLine> createState() => _UiProgressLineState();
}

class _UiProgressLineState extends State<UiProgressLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant UiProgressLine old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    if (!widget.active) return const SizedBox.shrink();
    final known = widget.progress >= 1;
    return SizedBox(
      height: Ui.progressHeight,
      child: known
          ? Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: Ui.normal,
                curve: Ui.curve,
                widthFactor: (widget.progress / 100).clamp(0.02, 1.0).toDouble(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.65),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final total = box.maxWidth;
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final w = (total * 0.28).clamp(60.0, 320.0).toDouble();
                    final left = -w + (total + w) * _c.value;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: p.accent.withValues(alpha: 0.14),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: 0,
                          width: w,
                          height: Ui.progressHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.65),
                                  blurRadius: 7,
                                ),
                              ],
                            ),
                            child: const SizedBox(height: Ui.progressHeight),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Standard clickable row: lists in the side panel, menus, settings,
/// bookmarks, history — one rhythm everywhere.
class UiRow extends StatelessWidget {
  const UiRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.selected = false,
    this.height,
    this.padding,
    this.dense = false,
    this.ticked = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool dense;

  /// A short rule at the leading edge instead of a full-width divider: a list
  /// of rows reads as a stack of plates, not a table.
  final bool ticked;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final h = height ?? (dense ? 40 : 52);
    return UiHoverable(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      onLongPress: onLongPress,
      builder: (context, hovering, pressed) {
        final plate = AnimatedContainer(
          duration: Ui.quick,
          curve: Ui.curve,
          // A minimum, not a fixed height: a long subtitle or a large text
          // size grows the row instead of running past it.
          constraints: BoxConstraints(minHeight: h),
          padding: padding ?? EdgeInsets.symmetric(horizontal: dense ? 10 : Ui.padLg),
          decoration: BoxDecoration(
            color: pressed
                ? p.activeFill
                : (selected
                    ? p.activeFill
                    : (hovering ? p.hoverFill : Colors.transparent)),
            borderRadius: Ui.petal(Ui.rControl),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, Ui.gap(10)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.text(
                        p,
                        size: dense ? Ui.sizeSmall : Ui.sizeBody,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ui.caption(p),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[Ui.gap(8), trailing!],
            ],
          ),
        );
        // The selected row carries a keel down its leading edge: the one cue
        // that says "this row is the one the window is showing".
        final keeled = Stack(
          children: [
            plate,
            if (selected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Ui.keel(p),
              ),
          ],
        );
        if (!ticked) return keeled;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            keeled,
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Ui.tick(p, color: p.hairlineSoft),
            ),
          ],
        );
      },
    );
  }
}

class UiSection extends StatelessWidget {
  const UiSection({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.description,
    this.padding,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final String? description;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      decoration: Ui.card(p),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Ui.padLg),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.hairlineSoft)),
            ),
            child: Row(
              children: [
                Ui.keel(p, color: p.accent.withValues(alpha: 0.55)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ui.section(p),
                  ),
                ),
                ...?actions,
              ],
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(Ui.padLg),
            child: child,
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                description!,
                style: Ui.caption(p),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded flat button used for secondary actions inside cards and dialogs.
class UiButton extends StatelessWidget {
  const UiButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final Object? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return UiHoverable(
      onTap: onTap,
      enabled: onTap != null,
      builder: (context, hovering, pressed) {
        final bg = filled
            ? (pressed
                ? p.accent.withValues(alpha: 0.85)
                : p.accent)
            : (hovering || pressed ? p.hoverFill : Colors.transparent);
        return AnimatedContainer(
          duration: Ui.quick,
          curve: Ui.curve,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Ui.petal(Ui.rControl),
            border: Border.all(color: filled ? Colors.transparent : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                uiGlyph(
                  icon,
                  size: 16,
                  color: filled ? p.onAccent : (onTap == null ? p.textFaint : p.text),
                ),
                Ui.gap(7),
              ],
              Text(
                label,
                style: Ui.text(
                  p,
                  size: Ui.sizeSmall,
                  weight: FontWeight.w600,
                  color: filled
                      ? p.onAccent
                      : (onTap == null ? p.textFaint : p.text),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Chip used by the bookmarks bar, filters and speed-dial headers.
class UiChip extends StatelessWidget {
  const UiChip({
    super.key,
    required this.label,
    this.leading,
    this.onTap,
    this.onClose,
    this.selected = false,
  });

  final String label;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return UiHoverable(
      onTap: onTap,
      builder: (context, hovering, pressed) => AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected
              ? p.activeFill
              : (hovering || pressed ? p.hoverFill : Colors.transparent),
          borderRadius: Ui.petal(
            Ui.rControl,
            at: selected ? UiCorner.topRight : UiCorner.bottomRight,
          ),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 1.2 : Ui.hair,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, Ui.gap(7)],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ui.text(
                  p,
                  size: Ui.sizeCaption + 0.5,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (onClose != null) ...[
              Ui.gap(4),
              uiGlyph('close', size: 13, color: p.textDim),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty states that explain the situation in a sentence — no codes, no
/// all-caps, no counters.
class UiEmpty extends StatelessWidget {
  const UiEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final Object icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: Ui.petal(Ui.rCard),
                  border: Border.all(color: p.border),
                ),
                child: uiGlyph(icon, size: 21, color: p.textDim),
              ),
              Ui.vgap(14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Ui.text(p, size: Ui.sizeTitle, weight: FontWeight.w600),
              ),
              Ui.vgap(6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Ui.text(p, size: Ui.sizeSmall, color: p.textDim),
              ),
              if (actionLabel != null && onAction != null) ...[
                Ui.vgap(16),
                UiButton(
                  label: actionLabel!,
                  onTap: onAction,
                  filled: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows and plates arrive in a short cascade instead of appearing all at once,
/// so opening a panel reads as something being laid out rather than dumped.
class UiStagger extends StatefulWidget {
  const UiStagger({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final Widget child;
  final bool enabled;

  @override
  State<UiStagger> createState() => _UiStaggerState();
}

class _UiStaggerState extends State<UiStagger> {
  Timer? _timer;
  late bool _shown;

  @override
  void initState() {
    super.initState();
    final mq = MediaQuery.maybeOf(context);
    final reduce = !widget.enabled ||
        (mq?.disableAnimations ?? false) ||
        (mq?.platformDispatcher.accessibilityFeatures.disableAnimations ?? false);
    _shown = reduce;
    if (reduce) return;
    // The timer is cancelled on dispose: a row that goes away mid-arrival
    // must not leave a pending callback behind.
    _timer = Timer(Ui.enter(widget.index) + Ui.quick, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Ui.normal,
      curve: Ui.curve,
      // minOpacity keeps an arriving row tappable from the first frame.
      minOpacity: 1.0,
      opacity: _shown ? 1 : 0,
      child: AnimatedSlide(
        duration: Ui.normal,
        curve: Ui.curve,
        offset: _shown ? Offset.zero : const Offset(0, 0.03),
        child: widget.child,
      ),
    );
  }
}

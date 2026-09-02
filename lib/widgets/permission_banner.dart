import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../state/browser_provider.dart';

/// Chromium-style top banner for pending site permission requests
/// (camera / microphone / location).
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final ask = browser.pendingPermission;
    if (ask == null) return const SizedBox.shrink();
    final palette = pal(context);

    return Material(
      elevation: 0,
      color: palette.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: Ui.tint(palette, palette.accent, radius: 9),
                child:
                    Icon(Icons.videocam_outlined, size: 17, color: palette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${ask.host} wants to use your ${ask.labels.join(' and ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ui.text(
                    palette,
                    size: Ui.sizeBody,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => browser.resolvePermission(false, always: true),
                child: const Text('Block'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => browser.resolvePermission(false),
                child: const Text('Deny once'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: () => browser.resolvePermission(true, always: true),
                child: const Text('Allow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

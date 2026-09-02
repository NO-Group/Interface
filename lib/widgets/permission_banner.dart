import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
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
      elevation: 6,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.videocam_outlined, size: 18, color: palette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${ask.host} wants to use your ${ask.labels.join(' and ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Blocked sites stay blocked until you change it',
                      style: TextStyle(color: palette.textDim, fontSize: 11),
                    ),
                  ],
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

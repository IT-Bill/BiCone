import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';

/// A menu action item used by [showAdaptiveMenu].
class AdaptiveMenuAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const AdaptiveMenuAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });
}

/// Shows a CupertinoActionSheet on mobile, or a popup menu on desktop.
void showAdaptiveMenu(
  BuildContext context, {
  String? title,
  required List<AdaptiveMenuAction> actions,
  Offset? position,
}) {
  final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  if (isDesktop && position != null) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showCupertinoModalPopup(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.1),
      builder: (ctx) => _DesktopPopupMenu(
        position: position,
        overlaySize: overlay.size,
        title: title,
        actions: actions,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  } else {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: actions.map((a) => CupertinoActionSheetAction(
          isDestructiveAction: a.isDestructive,
          onPressed: () {
            Navigator.pop(ctx);
            a.onPressed();
          },
          child: Text(a.label),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _DesktopPopupMenu extends StatelessWidget {
  final Offset position;
  final Size overlaySize;
  final String? title;
  final List<AdaptiveMenuAction> actions;
  final VoidCallback onClose;

  const _DesktopPopupMenu({
    required this.position,
    required this.overlaySize,
    this.title,
    required this.actions,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const menuWidth = 200.0;
    final menuHeight = (actions.length * 44.0) + (title != null ? 36.0 : 0.0) + 16;
    
    var left = position.dx;
    var top = position.dy;
    if (left + menuWidth > overlaySize.width) {
      left = overlaySize.width - menuWidth - 8;
    }
    if (top + menuHeight > overlaySize.height) {
      top = overlaySize.height - menuHeight - 8;
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: menuWidth,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                ...actions.map((a) => CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  alignment: Alignment.centerLeft,
                  borderRadius: BorderRadius.zero,
                  onPressed: () {
                    onClose();
                    a.onPressed();
                  },
                  child: Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: a.isDestructive
                          ? CupertinoColors.destructiveRed
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

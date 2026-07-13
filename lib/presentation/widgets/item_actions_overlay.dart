import 'package:flutter/material.dart';

/// One action in the long-press floating menu (see [showItemActionsOverlay]).
class ItemAction {
  const ItemAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.color,
  });

  final IconData icon;

  /// Tooltip and accessibility label (e.g. l10n.edit / l10n.delete).
  final String label;

  /// Fired after the overlay dismisses when this action is chosen.
  final VoidCallback onSelected;

  /// Icon tint; defaults to the theme's primary colour. Delete passes red.
  final Color? color;
}

/// Shows [actions] as floating circular buttons anchored to [anchor] — a global
/// rect, typically a long-pressed tile. The rest of the screen dims behind a
/// scrim while [anchorPreview] is redrawn at [anchor] above it, so the pressed
/// item stays bright and "pops". Choosing a button dismisses the overlay then
/// fires its callback; tapping the scrim or pressing back dismisses without
/// acting. The button cluster hugs the anchor's trailing edge and mirrors under
/// RTL. Generic on purpose — it knows nothing about contacts or entries (#5).
Future<void> showItemActionsOverlay(
  BuildContext context, {
  required Rect anchor,
  required Widget anchorPreview,
  required List<ItemAction> actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => _ItemActionsLayer(
      anchor: anchor,
      anchorPreview: anchorPreview,
      actions: actions,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _ItemActionsLayer extends StatelessWidget {
  const _ItemActionsLayer({
    required this.anchor,
    required this.anchorPreview,
    required this.actions,
  });

  final Rect anchor;
  final Widget anchorPreview;
  final List<ItemAction> actions;

  static const double buttonSize = 48;
  static const double _gap = 12;
  static const double _edgeInset = 16;
  static const double _screenMargin = 8;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final clusterWidth =
        actions.length * buttonSize + (actions.length - 1) * _gap;

    // Hug the anchor's trailing edge: right in LTR, left in RTL.
    var left = isRtl
        ? anchor.left + _edgeInset
        : anchor.right - _edgeInset - clusterWidth;
    left = left.clamp(_screenMargin, size.width - clusterWidth - _screenMargin);

    var top = anchor.center.dy - buttonSize / 2;
    top = top.clamp(
      media.padding.top + _screenMargin,
      size.height - buttonSize - _screenMargin,
    );

    return Stack(
      children: [
        // The pressed item, redrawn bright above the scrim (non-interactive).
        Positioned.fromRect(
          rect: anchor,
          child: IgnorePointer(child: anchorPreview),
        ),
        Positioned(
          left: left,
          top: top,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                _ActionButton(action: actions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final ItemAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = action.color ?? scheme.primary;
    return Tooltip(
      message: action.label,
      child: Semantics(
        button: true,
        label: action.label,
        child: Material(
          color: scheme.surface,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).pop();
              action.onSelected();
            },
            child: SizedBox(
              width: _ItemActionsLayer.buttonSize,
              height: _ItemActionsLayer.buttonSize,
              child: Icon(action.icon, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// A "＋" FAB that expands into two labeled quick-add actions — Add معاملة and
/// Add جهة اتصال (#25). Tapping the main button toggles a full-screen scrim with
/// the two [FloatingActionButton.extended] mini-actions stacked above it; the
/// main icon animates between `add` and `close`. Tapping the scrim (or a
/// mini-action) dismisses it.
///
/// The overlay is hosted via [OverlayPortal] so the scrim truly covers the
/// screen rather than being clipped to the Scaffold's FAB slot (whose bounded,
/// bottom-end layout can't host a full-screen child).
class QuickAddSpeedDial extends StatefulWidget {
  const QuickAddSpeedDial({
    super.key,
    required this.onAddTransaction,
    required this.onAddContact,
  });

  final VoidCallback onAddTransaction;
  final VoidCallback onAddContact;

  @override
  State<QuickAddSpeedDial> createState() => _QuickAddSpeedDialState();
}

class _QuickAddSpeedDialState extends State<QuickAddSpeedDial> {
  final _portal = OverlayPortalController();
  bool _open = false;

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    open ? _portal.show() : _portal.hide();
  }

  // Dismiss first, then run the action — the mini-actions are gone before the
  // pushed screen animates in.
  void _run(VoidCallback action) {
    _setOpen(false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: FloatingActionButton(
        key: const Key('home-speed-dial'),
        onPressed: () => _setOpen(!_open),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(_open ? Icons.close : Icons.add, key: ValueKey(_open)),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        // Full-screen tap-to-dismiss scrim behind the actions.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setOpen(false),
            child: const ColoredBox(color: Colors.black54),
          ),
        ),
        // The mini-actions sit at the bottom-end, just above the main FAB.
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Padding(
              // Clear the 56px main FAB plus its 16px margins above and below.
              padding: const EdgeInsetsDirectional.only(end: 16, bottom: 88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    key: const Key('quick-add-transaction'),
                    heroTag: 'quick-add-transaction',
                    onPressed: () => _run(widget.onAddTransaction),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.addEntry),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    key: const Key('quick-add-contact'),
                    heroTag: 'quick-add-contact',
                    onPressed: () => _run(widget.onAddContact),
                    icon: const Icon(Icons.person_add),
                    label: Text(l10n.addContact),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

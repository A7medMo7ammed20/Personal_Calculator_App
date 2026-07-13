import 'package:flutter/material.dart';

import '../../domain/period.dart';
import '../../l10n/gen/app_localizations.dart';

/// The period filter chip (#7): a visibility/time-range selector shared by the
/// home screen and the Analysis graph (#8). Picking [PeriodOption.custom] just
/// reports the choice; the owner opens the date-range picker (handled upstream),
/// so this widget stays stateless and reusable.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.period,
    required this.onSelected,
  });

  final PeriodOption period;
  final ValueChanged<PeriodOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(PeriodOption p) => switch (p) {
      PeriodOption.allTime => l10n.periodAllTime,
      PeriodOption.thisMonth => l10n.periodThisMonth,
      PeriodOption.lastMonth => l10n.periodLastMonth,
      PeriodOption.thisYear => l10n.periodThisYear,
      PeriodOption.custom => l10n.periodCustom,
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: PopupMenuButton<PeriodOption>(
          tooltip: l10n.periodLabel,
          initialValue: period,
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final p in PeriodOption.values)
              CheckedPopupMenuItem(
                value: p,
                checked: p == period,
                child: Text(label(p)),
              ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event, size: 18),
              const SizedBox(width: 6),
              Text(label(period)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

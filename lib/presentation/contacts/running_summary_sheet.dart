import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/balance.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../domain/running_summary.dart';
import '../../l10n/gen/app_localizations.dart';
import '../money_format.dart';
import '../theme/theme_context.dart';

/// Shows the running summary up to [tapped]: dated rows oldest→newest with the
/// tapped entry anchored at the bottom (older history scrolls up), and the two
/// gross directional totals + net closing balance pinned at the bottom. The
/// series is built from the full currency-scoped [entries]; [tapped] selects
/// how far it runs. See CONTEXT.md (Statement) and issue #16.
void showRunningSummarySheet(
  BuildContext context, {
  required List<Entry> entries,
  required Entry tapped,
  required Currency currency,
}) {
  final full = runningSummary(entries);
  final cut = full.indexWhere((r) => r.entry.id == tapped.id);
  final rows = cut < 0 ? full : full.sublist(0, cut + 1);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _RunningSummaryBody(rows: rows, currency: currency),
  );
}

class _RunningSummaryBody extends StatelessWidget {
  const _RunningSummaryBody({required this.rows, required this.currency});

  final List<RunningSummaryRow> rows;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final last = rows.isEmpty ? null : rows.last;
    final tappedDate = last == null
        ? ''
        : DateFormat.yMMMd(locale).format(last.entry.createdAt);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.summaryTitle(tappedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            // Reverse list: newest (the tapped entry) pinned at the bottom,
            // older history scrolling upward.
            Flexible(
              child: ListView.separated(
                reverse: true,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[rows.length - 1 - index]; // newest first visually at bottom
                  return _summaryRowTile(context, locale, row);
                },
              ),
            ),
            const Divider(height: 1),
            _PinnedTotals(row: last, currency: currency),
          ],
        ),
      ),
    );
  }

  Widget _summaryRowTile(
    BuildContext context,
    String locale,
    RunningSummaryRow row,
  ) {
    final e = row.entry;
    final toMe = e.direction == Direction.owedToMe;
    final color = toMe ? context.semanticColors.owedToMe : context.semanticColors.owedByMe;
    final date = DateFormat.yMMMd(locale).format(e.createdAt);
    final sign = toMe ? '+' : '−';
    return ListTile(
      dense: true,
      title: Text(e.description?.isNotEmpty == true ? e.description! : date),
      subtitle: Text(date),
      trailing: Text(
        '$sign${formatMoney(e.amount, e.currency)}',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The two gross directional totals + net closing balance, pinned at the bottom.
class _PinnedTotals extends StatelessWidget {
  const _PinnedTotals({required this.row, required this.currency});

  final RunningSummaryRow? row;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = row;
    final toMe = r?.cumulativeOwedToMe ?? 0;
    final byMe = r?.cumulativeOwedByMe ?? 0;
    final balance = r?.balance ?? const Balance(0);

    String netLabel() {
      if (balance.isSettled) return l10n.balanceSettled;
      final amount = formatMoney(balance.magnitude, currency);
      return balance.isOwedToMe
          ? l10n.balanceOwedToMe(amount)
          : l10n.balanceOwedByMe(amount);
    }

    final semantics = context.semanticColors;
    final netColor = balance.isSettled
        ? semantics.settled
        : (balance.isOwedToMe ? semantics.owedToMe : semantics.owedByMe);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _totalColumn(context, l10n.homeTotalOwedToMe,
                    formatMoney(toMe, currency), semantics.owedToMe),
              ),
              Expanded(
                child: _totalColumn(context, l10n.homeTotalOwedByMe,
                    formatMoney(byMe, currency), semantics.owedByMe),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            netLabel(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: netColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _totalColumn(
    BuildContext context, String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          amount,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

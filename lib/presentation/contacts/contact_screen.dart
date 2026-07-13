import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entries/add_entry_screen.dart';
import '../money_format.dart';

/// The heart of the ledger: one Contact's Entries plus a live per-Contact
/// [Balance]. Repayment is just an opposite-direction Entry — nothing special
/// in this UI. Single currency this slice (the currency lens arrives in #4).
class ContactScreen extends StatefulWidget {
  const ContactScreen({
    super.key,
    required this.contact,
    required this.repository,
    required this.currency,
  });

  final Contact contact;
  final EntryRepository repository;

  /// The active currency lens; this page shows only this currency's entries and
  /// balance, and new entries inherit it. See CONTEXT.md.
  final Currency currency;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  // Owed-to-me green and owed-by-me red, distinct in both light and dark.
  static const Color _green = Color(0xFF2E7D5B);
  static const Color _red = Color(0xFFC0392B);

  late Future<List<Entry>> _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _entries = widget.repository.listByContact(
      widget.contact.id!,
      currency: widget.currency,
    );
  }

  Future<void> _addEntry() async {
    final saved = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(
          contactId: widget.contact.id!,
          repository: widget.repository,
          currency: widget.currency,
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.contact.name)),
      body: FutureBuilder<List<Entry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <Entry>[];
          final balance = balanceOf(entries);
          return Column(
            children: [
              _BalanceHeader(
                balance: balance,
                label: _balanceLabel(l10n, balance),
                color: _balanceColor(balance),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.contactEntriesEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _entryTile(context, l10n, entries[index]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        tooltip: l10n.addEntry,
        icon: const Icon(Icons.add),
        label: Text(l10n.addEntry),
      ),
    );
  }

  String _balanceLabel(AppLocalizations l10n, Balance balance) {
    if (balance.isSettled) return l10n.balanceSettled;
    final amount = formatMoney(balance.magnitude, widget.currency);
    return balance.isOwedToMe
        ? l10n.balanceOwedToMe(amount)
        : l10n.balanceOwedByMe(amount);
  }

  Color _balanceColor(Balance balance) {
    if (balance.isSettled) return Theme.of(context).colorScheme.outline;
    return balance.isOwedToMe ? _green : _red;
  }

  Widget _entryTile(BuildContext context, AppLocalizations l10n, Entry entry) {
    final toMe = entry.direction == Direction.owedToMe;
    final color = toMe ? _green : _red;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(entry.createdAt);
    final sign = toMe ? '+' : '−';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: Icon(toMe ? Icons.south_west : Icons.north_east),
      ),
      title: Text(
        entry.description?.isNotEmpty == true
            ? entry.description!
            : (toMe ? l10n.directionOwedToMe : l10n.directionOwedByMe),
      ),
      subtitle: Text(date),
      trailing: Text(
        '$sign${formatMoney(entry.amount, entry.currency)}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Prominent card at the top of the Contact page carrying the [Balance] as a
/// magnitude plus colour + label — never a raw sign. See CONTEXT.md.
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.balance,
    required this.label,
    required this.color,
  });

  final Balance balance;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

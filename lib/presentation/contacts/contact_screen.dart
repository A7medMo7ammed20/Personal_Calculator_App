import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../domain/entry_sort.dart';
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

  final _searchController = TextEditingController();
  String _query = '';
  EntrySortField _sortField = EntrySortField.date;
  bool _ascending = false; // newest-first default (created_at DESC)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          final balance = balanceOf(entries); // balance is over ALL entries
          final visible = sortEntries(
            filterEntriesByDescription(entries, _query),
            _sortField,
            ascending: _ascending,
          );
          return Column(
            children: [
              _BalanceHeader(
                balance: balance,
                label: _balanceLabel(l10n, balance),
                color: _balanceColor(balance),
              ),
              _EntrySearchSortBar(
                controller: _searchController,
                sortField: _sortField,
                ascending: _ascending,
                onQueryChanged: (q) => setState(() => _query = q),
                onSortSelected: (field) => setState(() {
                  if (_sortField == field) {
                    _ascending = !_ascending; // tapping active field toggles
                  } else {
                    _sortField = field;
                    _ascending = true;
                  }
                }),
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
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _dismissibleEntry(context, l10n, visible[index]),
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

  Widget _dismissibleEntry(
    BuildContext context,
    AppLocalizations l10n,
    Entry entry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      // Swipe toward END = delete (red). Confirmed, then undoable.
      background: Container(
        color: _red.withValues(alpha: 0.90),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      // Swipe toward START = edit (blue). Never dismisses the tile.
      secondaryBackground: Container(
        color: Colors.blue.withValues(alpha: 0.85),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final ok = await _confirmDeleteEntry(l10n);
          return ok;
        } else {
          await _editEntry(entry);
          return false; // edit never dismisses
        }
      },
      onDismissed: (_) => _deleteEntry(entry),
      child: _entryTile(context, l10n, entry),
    );
  }

  Future<bool> _confirmDeleteEntry(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEntryTitle),
        content: Text(l10n.deleteEntryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteEntry(Entry entry) async {
    await widget.repository.delete(entry.id!);
    if (!mounted) return;
    setState(_load);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.entryDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            // Re-insert as a fresh row; nothing references entry ids.
            await widget.repository.add(entry.copyWith(id: null));
            if (mounted) setState(_load);
          },
        ),
      ));
  }

  Future<void> _editEntry(Entry entry) async {
    final updated = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(
          contactId: widget.contact.id!,
          repository: widget.repository,
          currency: widget.currency,
          existing: entry,
        ),
      ),
    );
    if (updated != null && mounted) setState(_load);
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

/// Search field plus a sort control (Date / Value / Description) for the
/// Contact's own entries (#15). Tapping the active sort field toggles asc/desc.
class _EntrySearchSortBar extends StatelessWidget {
  const _EntrySearchSortBar({
    required this.controller,
    required this.sortField,
    required this.ascending,
    required this.onQueryChanged,
    required this.onSortSelected,
  });

  final TextEditingController controller;
  final EntrySortField sortField;
  final bool ascending;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EntrySortField> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(EntrySortField f) => switch (f) {
      EntrySortField.date => l10n.sortByDate,
      EntrySortField.value => l10n.sortByValue,
      EntrySortField.description => l10n.sortByDescription,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchEntriesHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<EntrySortField>(
            tooltip: l10n.sortLabel,
            icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            initialValue: sortField,
            onSelected: onSortSelected,
            itemBuilder: (context) => [
              for (final f in EntrySortField.values)
                CheckedPopupMenuItem(
                  value: f,
                  checked: f == sortField,
                  child: Text(label(f)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

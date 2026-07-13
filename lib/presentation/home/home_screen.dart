import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/contact_sort.dart';
import '../../domain/currency.dart';
import '../../domain/ledger_totals.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contact_screen.dart';
import '../money_format.dart';
import '../widgets/item_actions_overlay.dart';

/// Owed-to-me green and owed-by-me red, shared across the ledger screens.
const Color _green = Color(0xFF2E7D5B);
const Color _red = Color(0xFFC0392B);

/// Home screen: a global currency lens, per-currency grand totals, and the
/// Contact list showing each Contact's balance in the selected currency. The
/// two currencies never mix — switching the lens refilters everything.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.entryRepository,
  });

  final ContactRepository repository;
  final EntryRepository entryRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Everything the home screen renders for one currency lens, loaded together.
class _HomeData {
  const _HomeData(this.contacts, this.balances, this.activity, this.totals);

  final List<Contact> contacts;
  final Map<int, Balance> balances;
  final Map<int, DateTime> activity;
  final LedgerTotals totals;
}

class _HomeScreenState extends State<HomeScreen> {
  Currency _currency = Currency.sar;
  late Future<_HomeData> _data;

  // Search + sort live on the screen (ephemeral): they persist across a lens
  // switch but reset on restart. Default: most-recent-activity, newest first.
  final _searchController = TextEditingController();
  String _query = '';
  ContactSortField _sortField = ContactSortField.activity;
  bool _ascending = false;

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
    _data = _fetch(_currency);
  }

  Future<_HomeData> _fetch(Currency currency) async {
    final contacts = await widget.repository.list();
    final balances = await widget.entryRepository.balancesByCurrency(currency);
    final activity = await widget.entryRepository.lastActivityByCurrency(
      currency,
    );
    return _HomeData(contacts, balances, activity, totalsOf(balances.values));
  }

  /// Each field's natural direction the first time it is chosen; tapping the
  /// active field then toggles from here (activity newest, name A–Z, balance
  /// biggest first).
  bool _defaultAscendingFor(ContactSortField field) =>
      field == ContactSortField.name;

  void _selectSort(ContactSortField field) {
    setState(() {
      if (_sortField == field) {
        _ascending = !_ascending;
      } else {
        _sortField = field;
        _ascending = _defaultAscendingFor(field);
      }
    });
  }

  void _selectCurrency(Currency currency) {
    if (currency == _currency) return;
    setState(() {
      _currency = currency;
      _load();
    });
  }

  Future<void> _addContact() async {
    final saved = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(repository: widget.repository),
      ),
    );
    if (saved != null && mounted) setState(_load);
  }

  Future<void> _openContact(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactScreen(
          contact: contact,
          repository: widget.entryRepository,
          currency: _currency,
        ),
      ),
    );
    // Entries may have changed; refresh the balances and totals for the lens.
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          _CurrencyLens(selected: _currency, onSelected: _selectCurrency),
          Expanded(
            child: FutureBuilder<_HomeData>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data;
                if (data == null || data.contacts.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.homeEmpty,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final visible = sortContacts(
                  filterContacts(data.contacts, _query),
                  _sortField,
                  balances: data.balances,
                  activity: data.activity,
                  ascending: _ascending,
                );
                return Column(
                  children: [
                    _TotalsHeader(totals: data.totals, currency: _currency),
                    _ContactSearchSortBar(
                      controller: _searchController,
                      sortField: _sortField,
                      ascending: _ascending,
                      onQueryChanged: (q) => setState(() => _query = q),
                      onSortSelected: _selectSort,
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                l10n.homeNoMatches,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final contact = visible[index];
                                final balance = data.balances[contact.id] ??
                                    const Balance(0);
                                return _contactTile(
                                  context,
                                  l10n,
                                  contact,
                                  balance,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        tooltip: l10n.addContact,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  /// Long-press a contact tile → floating Edit/Delete buttons beside it (#5).
  /// [tileContext] is the tile's own element, so its RenderBox gives the anchor
  /// rect. Delete keeps the cascade-count confirm dialog then the undo SnackBar.
  void _showContactActions(
    BuildContext tileContext,
    AppLocalizations l10n,
    Contact contact,
    Balance balance,
  ) {
    final box = tileContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;

    showItemActionsOverlay(
      tileContext,
      anchor: rect,
      anchorPreview: SizedBox.fromSize(
        size: rect.size,
        child: Material(
          color: Theme.of(tileContext).colorScheme.surface,
          child: _contactTile(tileContext, l10n, contact, balance),
        ),
      ),
      actions: [
        ItemAction(
          icon: Icons.edit,
          label: l10n.edit,
          onSelected: () => _editContact(contact),
        ),
        ItemAction(
          icon: Icons.delete,
          color: _red,
          label: l10n.delete,
          onSelected: () => _deleteContactWithConfirm(l10n, contact),
        ),
      ],
    );
  }

  Future<void> _deleteContactWithConfirm(
    AppLocalizations l10n,
    Contact contact,
  ) async {
    if (await _confirmDeleteContact(l10n, contact)) {
      await _deleteContact(contact);
    }
  }

  Future<bool> _confirmDeleteContact(
    AppLocalizations l10n,
    Contact contact,
  ) async {
    final count = await widget.entryRepository
        .listByContact(contact.id!)
        .then((list) => list.length);
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteContactTitle),
        content: Text(l10n.deleteContactMessage(count)),
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

  Future<void> _deleteContact(Contact contact) async {
    // Capture the entries first so undo can restore the cascade.
    final removedEntries = await widget.entryRepository.listByContact(
      contact.id!,
    );
    await widget.repository.delete(contact.id!);
    if (!mounted) return;
    setState(_load);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.contactDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              final restored = await widget.repository.add(
                contact.copyWith(id: null),
              );
              for (final e in removedEntries) {
                await widget.entryRepository.add(
                  e.copyWith(id: null, contactId: restored.id),
                );
              }
              if (mounted) setState(_load);
            },
          ),
        ),
      );
  }

  Future<void> _editContact(Contact contact) async {
    final updated = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) =>
            AddContactScreen(repository: widget.repository, existing: contact),
      ),
    );
    if (updated != null && mounted) setState(_load);
  }

  Widget _contactTile(
    BuildContext context,
    AppLocalizations l10n,
    Contact contact,
    Balance balance,
  ) {
    final String label;
    final Color color;
    if (balance.isSettled) {
      label = l10n.balanceSettled;
      color = Theme.of(context).colorScheme.outline;
    } else {
      final amount = formatMoney(balance.magnitude, _currency);
      label = balance.isOwedToMe
          ? l10n.balanceOwedToMe(amount)
          : l10n.balanceOwedByMe(amount);
      color = balance.isOwedToMe ? _green : _red;
    }
    // Builder so the long-press callback gets a context whose RenderObject is
    // this tile (not the enclosing list), giving the overlay its anchor rect.
    return Builder(
      builder: (tileContext) => ListTile(
        leading: CircleAvatar(child: Text(_initial(contact.name))),
        title: Text(contact.name),
        subtitle: contact.phone == null ? null : Text(contact.phone!),
        trailing: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _openContact(contact),
        onLongPress: () =>
            _showContactActions(tileContext, l10n, contact, balance),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}

/// Search field plus a sort control (Recent / Name / Balance) for the home
/// Contact list (#6). Tapping the active sort field toggles asc/desc — mirrors
/// the per-contact entry sort bar.
class _ContactSearchSortBar extends StatelessWidget {
  const _ContactSearchSortBar({
    required this.controller,
    required this.sortField,
    required this.ascending,
    required this.onQueryChanged,
    required this.onSortSelected,
  });

  final TextEditingController controller;
  final ContactSortField sortField;
  final bool ascending;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ContactSortField> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(ContactSortField f) => switch (f) {
      ContactSortField.activity => l10n.sortByActivity,
      ContactSortField.name => l10n.sortByName,
      ContactSortField.balanceSize => l10n.sortByBalanceSize,
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
                hintText: l10n.searchContactsHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<ContactSortField>(
            tooltip: l10n.sortLabel,
            icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            initialValue: sortField,
            onSelected: onSortSelected,
            itemBuilder: (context) => [
              for (final f in ContactSortField.values)
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

/// The SAR/YER lens switch at the top of home.
class _CurrencyLens extends StatelessWidget {
  const _CurrencyLens({required this.selected, required this.onSelected});

  final Currency selected;
  final ValueChanged<Currency> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<Currency>(
        segments: [
          for (final currency in Currency.values)
            ButtonSegment(value: currency, label: Text(currency.code)),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }
}

/// Per-currency grand totals: what I'm owed and what I owe, side by side.
class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.totals, required this.currency});

  final LedgerTotals totals;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _TotalTile(
              label: l10n.homeTotalOwedToMe,
              amount: formatMoney(totals.owedToMe, currency),
              color: _green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TotalTile(
              label: l10n.homeTotalOwedByMe,
              amount: formatMoney(totals.owedByMe, currency),
              color: _red,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

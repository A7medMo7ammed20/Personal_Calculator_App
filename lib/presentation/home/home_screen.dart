import 'package:flutter/material.dart' hide Flow;

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/contact_sort.dart';
import '../../domain/currency.dart';
import '../../domain/flow.dart';
import '../../domain/ledger_totals.dart';
import '../../domain/period.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contact_screen.dart';
import '../money_format.dart';
import '../theme/theme_context.dart';
import '../widgets/item_actions_overlay.dart';

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
/// [balances] and [activity] are always all-time — the [[Period filter]] never
/// touches them. When a bounded period is active, [flow] and [activeIds] carry
/// the window's gross [[Flow]] and the set of Contacts with activity in range;
/// both are null at All time.
class _HomeData {
  const _HomeData(
    this.contacts,
    this.balances,
    this.activity,
    this.totals, {
    this.flow,
    this.activeIds,
  });

  final List<Contact> contacts;
  final Map<int, Balance> balances;
  final Map<int, DateTime> activity;
  final LedgerTotals totals;
  final Flow? flow;
  final Set<int>? activeIds;
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

  // Period filter (#7): a visibility filter, never a balance filter. Ephemeral
  // like search/sort; persists across a lens switch, resets on restart.
  PeriodOption _period = PeriodOption.allTime;
  DateTime? _customStart;
  DateTime? _customEnd;

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
    final totals = totalsOf(balances.values);

    // A bounded period adds a visibility set + flow header; balances stay
    // all-time. All time leaves both null (no filter, net-position header).
    final range = resolvePeriod(
      _period,
      DateTime.now(),
      customStart: _customStart,
      customEnd: _customEnd,
    );
    if (range == null) {
      return _HomeData(contacts, balances, activity, totals);
    }
    final windowed = await widget.entryRepository.entriesInRange(
      currency,
      range,
    );
    return _HomeData(
      contacts,
      balances,
      activity,
      totals,
      flow: flowTotalsOf(windowed),
      activeIds: {for (final e in windowed) e.contactId},
    );
  }

  Future<void> _selectPeriod(PeriodOption option) async {
    if (option == PeriodOption.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        initialDateRange: _customStart != null && _customEnd != null
            ? DateTimeRange(start: _customStart!, end: _customEnd!)
            : null,
      );
      if (picked == null) return; // cancelled — keep the current period
      setState(() {
        _period = PeriodOption.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
        _load();
      });
      return;
    }
    setState(() {
      _period = option;
      _load();
    });
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
                // Period is a visibility filter (applied first), then search,
                // then sort. A null activeIds means All time (no filtering).
                final inPeriod = data.activeIds == null
                    ? data.contacts
                    : data.contacts
                        .where((c) => data.activeIds!.contains(c.id))
                        .toList();
                final visible = sortContacts(
                  filterContacts(inPeriod, _query),
                  _sortField,
                  balances: data.balances,
                  activity: data.activity,
                  ascending: _ascending,
                );
                // No contacts survive the period → empty-period; otherwise it
                // was the search box that cleared them → no-matches.
                final emptyMessage = inPeriod.isEmpty
                    ? l10n.homeNoActivityInPeriod
                    : l10n.homeNoMatches;
                return Column(
                  children: [
                    // Flow header when a bounded period is active; the all-time
                    // net-position header otherwise. Flow follows the period
                    // alone — search never changes it.
                    if (data.flow != null)
                      _FlowHeader(flow: data.flow!, currency: _currency)
                    else
                      _TotalsHeader(totals: data.totals, currency: _currency),
                    _PeriodSelector(period: _period, onSelected: _selectPeriod),
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
                                emptyMessage,
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
          color: Theme.of(tileContext).colorScheme.error,
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
    final semantics = context.semanticColors;
    if (balance.isSettled) {
      label = l10n.balanceSettled;
      color = semantics.settled;
    } else {
      final amount = formatMoney(balance.magnitude, _currency);
      label = balance.isOwedToMe
          ? l10n.balanceOwedToMe(amount)
          : l10n.balanceOwedByMe(amount);
      color = balance.isOwedToMe ? semantics.owedToMe : semantics.owedByMe;
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

/// The home period filter (#7): a visibility filter over the Contact list plus
/// the [[Flow]] header mode. Custom opens a date-range picker (handled upstream).
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onSelected});

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

/// The grand-total header in [[Flow]] mode: gross lent / received for the active
/// window. Replaces the net-position [_TotalsHeader] when a period is bounded.
class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.flow, required this.currency});

  final Flow flow;
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
              label: l10n.flowLent,
              amount: formatMoney(flow.lent, currency),
              color: context.semanticColors.owedToMe,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TotalTile(
              label: l10n.flowReceived,
              amount: formatMoney(flow.received, currency),
              color: context.semanticColors.owedByMe,
            ),
          ),
        ],
      ),
    );
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
              color: context.semanticColors.owedToMe,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TotalTile(
              label: l10n.homeTotalOwedByMe,
              amount: formatMoney(totals.owedByMe, currency),
              color: context.semanticColors.owedByMe,
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

import 'package:flutter/material.dart' hide Flow;

import '../../branding/daftar_mark.dart';
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
import '../analysis/analysis_graph_screen.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contact_screen.dart';
import '../money_format.dart';
import '../settings/settings_screen.dart';
import '../theme/theme_context.dart';
import '../theme/theme_controller.dart';
import '../widgets/item_actions_overlay.dart';

/// Global destinations behind the home overflow menu (⋮). The Analysis graph
/// (#8) and Settings live here; Backup joins when it ships (ADR 0003/0004).
enum _HomeMenuAction { analysis, settings }

/// Home screen: a global currency lens, per-currency grand totals, and the
/// Contact list showing each Contact's balance in the selected currency. The
/// two currencies never mix — switching the lens refilters everything.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.entryRepository,
    this.themeController,
  });

  final ContactRepository repository;
  final EntryRepository entryRepository;

  /// Drives the Settings screen reached from the overflow menu. Optional so
  /// focused widget tests can pump the list without wiring theming; the real
  /// app always supplies it (see `DebtLedgerApp`).
  final ThemeController? themeController;

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

  // Body horizontal-swipe → currency lens change. We accumulate the drag delta
  // and decide on release, so a plain drag (no fling velocity) still switches.
  // The list scrolls vertically, so a horizontal pan is free to mean "change
  // currency" without fighting the scroll or a row long-press (ADR 0003).
  double _swipeDx = 0;

  void _onSwipeEnd(BuildContext context) {
    const threshold = 48.0; // ignore incidental horizontal jitter
    if (_swipeDx.abs() < threshold) return;
    // In RTL the visual "next" tab sits to the left, so the sign inverts.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = rtl ? _swipeDx > 0 : _swipeDx < 0;
    final index = Currency.values.indexOf(_currency);
    final next = index + (forward ? 1 : -1);
    if (next < 0 || next >= Currency.values.length) return;
    _selectCurrency(Currency.values[next]);
  }

  void _onMenuAction(_HomeMenuAction action, AppLocalizations l10n) {
    switch (action) {
      case _HomeMenuAction.analysis:
        _openAnalysis();
      case _HomeMenuAction.settings:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SettingsScreen(controller: widget.themeController!),
          ),
        );
    }
  }

  /// Opens the Analysis graph carrying the current lens + period; on return it
  /// adopts any change made there so home and the graph stay in sync (ADR 0004
  /// — return-on-pop, no lifted controller).
  Future<void> _openAnalysis() async {
    final result = await Navigator.of(context).push<AnalysisGraphResult>(
      MaterialPageRoute(
        builder: (_) => AnalysisGraphScreen(
          entryRepository: widget.entryRepository,
          contactRepository: widget.repository,
          currency: _currency,
          period: _period,
          customStart: _customStart,
          customEnd: _customEnd,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _currency = result.currency;
      _period = result.period;
      _customStart = result.customStart;
      _customEnd = result.customEnd;
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
      appBar: AppBar(
        // Brand mark in the leading slot — always Teal/white regardless of the
        // user's in-app accent, per the brand rules. Title text stays as-is.
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: DaftarIconTile(size: 32, radius: 8),
        ),
        title: Text(l10n.appTitle),
        actions: [
          if (widget.themeController != null)
            PopupMenuButton<_HomeMenuAction>(
              // Rarely-used global destinations live behind the overflow menu
              // (ADR 0003); Backup joins Settings here when it lands.
              onSelected: (action) => _onMenuAction(action, l10n),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _HomeMenuAction.analysis,
                  child: Row(
                    children: [
                      const Icon(Icons.show_chart),
                      SizedBox(width: context.spacing.md),
                      Text(l10n.analysisTitle),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _HomeMenuAction.settings,
                  child: Row(
                    children: [
                      const Icon(Icons.settings),
                      SizedBox(width: context.spacing.md),
                      Text(l10n.settingsTitle),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      // Horizontal swipe anywhere on the body flips the currency lens; the
      // ListView owns vertical drags, so the two never collide (ADR 0003).
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _swipeDx = 0,
        onHorizontalDragUpdate: (d) => _swipeDx += d.primaryDelta ?? 0,
        onHorizontalDragEnd: (_) => _onSwipeEnd(context),
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
                // One summary card: the all-time net position, or gross Flow
                // (lent/received) when a period is bounded. Flow follows the
                // period alone — search never changes it.
                _SummaryCard(
                  currency: _currency,
                  totals: data.totals,
                  flow: data.flow,
                ),
                _HomeToolbar(
                  period: _period,
                  onPeriodSelected: _selectPeriod,
                  searchController: _searchController,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        tooltip: l10n.addContact,
        child: const Icon(Icons.person_add),
      ),
      // The currency lens is the whole bottom bar: a swipeable SAR/YER tab bar
      // with an animated active indicator (ADR 0003).
      bottomNavigationBar: _CurrencyLens(
        selected: _currency,
        onSelected: _selectCurrency,
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
      // Single-line row: avatar · name · coloured signed balance. The phone is
      // deliberately not shown in-app — it lives only in PDF/WhatsApp share
      // (design-system.md · Density). It remains searchable via filterContacts.
      builder: (tileContext) => ListTile(
        leading: CircleAvatar(child: Text(_initial(contact.name))),
        title: Text(
          contact.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
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

/// The single home toolbar (ADR 0003): a period filter chip, a search field,
/// and a sort control on one row. Collapses what used to be two stacked bands.
class _HomeToolbar extends StatelessWidget {
  const _HomeToolbar({
    required this.period,
    required this.onPeriodSelected,
    required this.searchController,
    required this.sortField,
    required this.ascending,
    required this.onQueryChanged,
    required this.onSortSelected,
  });

  final PeriodOption period;
  final ValueChanged<PeriodOption> onPeriodSelected;
  final TextEditingController searchController;
  final ContactSortField sortField;
  final bool ascending;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ContactSortField> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String periodLabel(PeriodOption p) => switch (p) {
      PeriodOption.allTime => l10n.periodAllTime,
      PeriodOption.thisMonth => l10n.periodThisMonth,
      PeriodOption.lastMonth => l10n.periodLastMonth,
      PeriodOption.thisYear => l10n.periodThisYear,
      PeriodOption.custom => l10n.periodCustom,
    };
    String sortLabel(ContactSortField f) => switch (f) {
      ContactSortField.activity => l10n.sortByActivity,
      ContactSortField.name => l10n.sortByName,
      ContactSortField.balanceSize => l10n.sortByBalanceSize,
    };
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
      child: Row(
        children: [
          // Period chip: opens the period menu; its label doubles as the
          // current-period readout.
          PopupMenuButton<PeriodOption>(
            tooltip: l10n.periodLabel,
            initialValue: period,
            onSelected: onPeriodSelected,
            itemBuilder: (context) => [
              for (final p in PeriodOption.values)
                CheckedPopupMenuItem(
                  value: p,
                  checked: p == period,
                  child: Text(periodLabel(p)),
                ),
            ],
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(context.radius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, size: 18),
                  SizedBox(width: spacing.xs),
                  Text(periodLabel(period)),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchContactsHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius.md),
                ),
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
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
                  child: Text(sortLabel(f)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The currency lens as a swipeable bottom tab bar (ADR 0003): SAR / YER with
/// Material 3's animated active-tab indicator. Selecting a tab — or swiping the
/// body — switches the global lens; the two currencies never mix.
class _CurrencyLens extends StatelessWidget {
  const _CurrencyLens({required this.selected, required this.onSelected});

  final Currency selected;
  final ValueChanged<Currency> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    return NavigationBar(
      selectedIndex: Currency.values.indexOf(selected),
      onDestinationSelected: (i) => onSelected(Currency.values[i]),
      destinations: [
        for (final currency in Currency.values)
          NavigationDestination(
            icon: Text(currency.symbol, style: textTheme.titleMedium),
            selectedIcon: Text(
              currency.symbol,
              style: textTheme.titleMedium?.copyWith(color: primary),
            ),
            label: currency.code,
          ),
      ],
    );
  }
}

/// The unified home summary card (ADR 0003): one card showing the active
/// currency's all-time net position (Owed to you / You owe), or gross [[Flow]]
/// (Lent / Received) when a period is bounded.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.currency,
    required this.totals,
    this.flow,
  });

  final Currency currency;
  final LedgerTotals totals;

  /// Non-null when a bounded period is active — the card then shows Flow.
  final Flow? flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantics = context.semanticColors;
    final spacing = context.spacing;
    final bounded = flow != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        spacing.sm,
      ),
      child: Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(context.radius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: bounded ? l10n.flowLent : l10n.homeTotalOwedToMe,
                amount: formatMoney(
                  bounded ? flow!.lent : totals.owedToMe,
                  currency,
                ),
                color: semantics.owedToMe,
              ),
            ),
            SizedBox(width: spacing.lg),
            Expanded(
              child: _SummaryTile(
                label: bounded ? l10n.flowReceived : l10n.homeTotalOwedByMe,
                amount: formatMoney(
                  bounded ? flow!.received : totals.owedByMe,
                  currency,
                ),
                color: semantics.owedByMe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One half of the [_SummaryCard]: a label over a coloured, tabular-figure
/// amount. Amounts scale down rather than overflow on narrow screens.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: context.spacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            amount,
            style: textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

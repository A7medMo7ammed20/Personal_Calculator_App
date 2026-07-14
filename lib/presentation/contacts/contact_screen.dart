import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// Hide intl's TextDirection (LTR/RTL constants) so `TextDirection.rtl` below
// resolves to Flutter's enum, not intl's bidi class.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart' show Printing;
import 'package:url_launcher/url_launcher.dart';

import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../domain/entry_sort.dart';
import '../../domain/period.dart';
import '../../domain/statement.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contact_share.dart';
import '../entries/add_entry_screen.dart';
import '../money_format.dart';
import '../profile/ensure_profile_name.dart';
import '../profile/profile_controller.dart';
import '../statements/statement_pdf.dart';
import '../theme/theme_context.dart';
import '../widgets/period_selector.dart';
import 'running_summary_sheet.dart';

/// The heart of the ledger: one Contact's Entries plus a live per-Contact
/// [Balance]. Repayment is just an opposite-direction Entry — nothing special
/// in this UI. Single currency this slice (the currency lens arrives in #4).
class ContactScreen extends StatefulWidget {
  const ContactScreen({
    super.key,
    required this.contact,
    required this.repository,
    required this.currency,
    this.profileController,
    this.onSharePdf,
    this.onLaunchUrl,
  });

  final Contact contact;
  final EntryRepository repository;

  /// The active currency lens; this page shows only this currency's entries and
  /// balance, and new entries inherit it. See CONTEXT.md.
  final Currency currency;

  /// Drives the first-export name prompt (#9/#10). When null the PDF export
  /// action is hidden, so focused entry tests can pump without wiring it.
  final ProfileController? profileController;

  /// Delivers the finished PDF. Defaults to the OS share sheet
  /// (`Printing.sharePdf`); injected in tests to capture the bytes without a
  /// platform channel.
  final Future<void> Function(Uint8List bytes, String filename)? onSharePdf;

  /// Launches a `tel:`/`wa.me` [Uri] for the action strip. Defaults to
  /// `url_launcher`'s external-application launch; injected in tests to capture
  /// the URI without a platform channel (mirrors [onSharePdf]).
  final Future<void> Function(Uri uri)? onLaunchUrl;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late Future<List<Entry>> _entries;

  /// Mirror of the resolved entry list, kept so the app-bar export action can
  /// hide itself when this currency lens has nothing to state.
  List<Entry> _loaded = const [];

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
    final future = widget.repository.listByContact(
      widget.contact.id!,
      currency: widget.currency,
    );
    _entries = future;
    future.then((list) {
      if (mounted) setState(() => _loaded = list);
    });
  }

  /// Exports the PDF statement for this Contact in the current lens currency
  /// (#10). Picks a date range (default all time), makes sure a creditor name
  /// exists (#9's prompt-once seam), builds the pure statement model, renders
  /// it, and hands the bytes to [ContactScreen.onSharePdf] / the share sheet.
  Future<void> _exportStatement() async {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ExportOptionsSheet(),
    );
    if (choice == null || !mounted) return;

    final profile = await ensureProfileName(context, widget.profileController!);
    if (profile == null || !mounted) return;

    final range = resolvePeriod(
      choice.period,
      DateTime.now(),
      customStart: choice.customStart,
      customEnd: choice.customEnd,
    );
    final all = await widget.repository.listByContact(
      widget.contact.id!,
      currency: widget.currency,
    );
    final doc = buildStatement(
      profile: profile,
      contact: widget.contact,
      entries: all,
      currency: widget.currency,
      range: range,
      isRtl: isRtl,
    );
    final bytes = await renderStatementPdf(doc, l10n, localeName);
    final share = widget.onSharePdf ??
        (b, f) async {
          await Printing.sharePdf(bytes: b, filename: f);
        };
    // ASCII-safe, stable file name; the document content stays localized/RTL.
    await share(bytes, 'statement-${widget.currency.code}-${widget.contact.id}.pdf');
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

  Future<void> _launch(Uri uri) async {
    final launch = widget.onLaunchUrl ??
        (u) async {
          await launchUrl(u, mode: LaunchMode.externalApplication);
        };
    await launch(uri);
  }

  // tel: uses the RAW stored number (dialer is unaffected by format, ADR 0008).
  Future<void> _call(String phone) => _launch(Uri(scheme: 'tel', path: phone));

  // wa.me uses digits only (no country-code inference, ADR 0008) with a
  // pre-filled, editable balance message in the active lens + app language.
  Future<void> _whatsApp(String phone, Balance balance) {
    final message = buildWhatsAppMessage(
      contactName: widget.contact.name,
      balance: balance,
      currency: widget.currency,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final uri = Uri.https('wa.me', '/${normalizePhoneForWa(phone)}', {
      'text': message,
    });
    return _launch(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The export action appears only when a profile controller is wired and the
    // lens currency actually has entries to state (ADR 0006).
    final canExport = widget.profileController != null && _loaded.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        actions: [
          if (canExport)
            IconButton(
              key: const Key('export-statement'),
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: l10n.exportStatement,
              onPressed: _exportStatement,
            ),
        ],
      ),
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
              if (widget.contact.phone != null)
                _ContactActionStrip(
                  phone: widget.contact.phone!,
                  onCall: () => _call(widget.contact.phone!),
                  onWhatsApp: () => _whatsApp(widget.contact.phone!, balance),
                ),
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
                    : SlidableAutoCloseBehavior(
                        child: ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) => _entryTile(
                            context,
                            l10n,
                            entries,
                            visible[index],
                          ),
                        ),
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
    final semantics = context.semanticColors;
    if (balance.isSettled) return semantics.settled;
    return balance.isOwedToMe ? semantics.owedToMe : semantics.owedByMe;
  }

  Future<void> _deleteEntry(Entry entry) async {
    await widget.repository.delete(entry.id!);
    if (!mounted) return;
    setState(_load);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.entryDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              // Re-insert as a fresh row; nothing references entry ids.
              await widget.repository.add(entry.copyWith(id: null));
              if (mounted) setState(_load);
            },
          ),
        ),
      );
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

  Widget _entryTile(
    BuildContext context,
    AppLocalizations l10n,
    List<Entry> allEntries,
    Entry entry,
  ) {
    final toMe = entry.direction == Direction.owedToMe;
    final color = toMe
        ? context.semanticColors.owedToMe
        : context.semanticColors.owedByMe;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(entry.createdAt);
    final sign = toMe ? '+' : '−';

    // Swipe the row to reveal Edit / Delete beside it (ADR 0005); end semantics
    // mirror the pane under RTL/LTR. Tapping the row still opens the running
    // summary. Entry delete is immediate + undoable — no confirm dialog.
    return Slidable(
      key: ValueKey('entry-${entry.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _editEntry(entry),
            icon: Icons.edit,
            label: l10n.edit,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          SlidableAction(
            onPressed: (_) => _deleteEntry(entry),
            icon: Icons.delete,
            label: l10n.delete,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ],
      ),
      child: ListTile(
        onTap: () => showRunningSummarySheet(
          context,
          entries: allEntries,
          tapped: entry,
          currency: widget.currency,
        ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Quick informal actions on a Contact (ADR 0008): tap the number to open the
/// dialer (`tel:`) and a WhatsApp button to open a pre-filled balance nudge
/// (`wa.me`). The whole strip is hidden by the caller when the Contact has no
/// phone.
class _ContactActionStrip extends StatelessWidget {
  const _ContactActionStrip({
    required this.phone,
    required this.onCall,
    required this.onWhatsApp,
  });

  final String phone;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.md, spacing.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('contact-call'),
              onTap: onCall,
              borderRadius: BorderRadius.circular(context.radius.md),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.call, size: 20),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        phone,
                        semanticsLabel: '${l10n.callContact}: $phone',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          FilledButton.tonalIcon(
            key: const Key('contact-whatsapp'),
            onPressed: onWhatsApp,
            icon: const Icon(Icons.chat),
            label: Text(l10n.whatsappShare),
          ),
        ],
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

/// The user's export choice from the options sheet: a [PeriodOption] plus the
/// custom range when [PeriodOption.custom] is picked. `resolvePeriod` turns it
/// into the `DateRange?` the statement builder clips by.
class _ExportChoice {
  const _ExportChoice(this.period, {this.customStart, this.customEnd});

  final PeriodOption period;
  final DateTime? customStart;
  final DateTime? customEnd;
}

/// The single, minimal export surface (ADR 0006): reuse the shared
/// [PeriodSelector] (default All time) and a Share button. Tapping Share pops
/// the chosen range back to the caller, which then runs the name prompt and the
/// render. Custom opens the same date-range picker home/analysis use.
class _ExportOptionsSheet extends StatefulWidget {
  const _ExportOptionsSheet();

  @override
  State<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<_ExportOptionsSheet> {
  PeriodOption _period = PeriodOption.allTime;
  DateTime? _customStart;
  DateTime? _customEnd;

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
      });
      return;
    }
    setState(() => _period = option);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.exportStatement,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            PeriodSelector(period: _period, onSelected: _selectPeriod),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('export-share'),
              onPressed: () => Navigator.of(context).pop(
                _ExportChoice(
                  _period,
                  customStart: _customStart,
                  customEnd: _customEnd,
                ),
              ),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.exportStatement),
            ),
          ],
        ),
      ),
    );
  }
}

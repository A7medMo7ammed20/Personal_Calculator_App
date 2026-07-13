import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/balance.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../domain/ledger_totals.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contact_screen.dart';
import '../money_format.dart';

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
  const _HomeData(this.contacts, this.balances, this.totals);

  final List<Contact> contacts;
  final Map<int, Balance> balances;
  final LedgerTotals totals;
}

class _HomeScreenState extends State<HomeScreen> {
  Currency _currency = Currency.sar;
  late Future<_HomeData> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = _fetch(_currency);
  }

  Future<_HomeData> _fetch(Currency currency) async {
    final contacts = await widget.repository.list();
    final balances = await widget.entryRepository.balancesByCurrency(currency);
    return _HomeData(contacts, balances, totalsOf(balances.values));
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
                return Column(
                  children: [
                    _TotalsHeader(totals: data.totals, currency: _currency),
                    Expanded(
                      child: ListView.builder(
                        itemCount: data.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = data.contacts[index];
                          final balance =
                              data.balances[contact.id] ?? const Balance(0);
                          return _contactTile(context, l10n, contact, balance);
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
    return ListTile(
      leading: CircleAvatar(child: Text(_initial(contact.name))),
      title: Text(contact.name),
      subtitle: contact.phone == null ? null : Text(contact.phone!),
      trailing: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () => _openContact(contact),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
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
            ButtonSegment(
              value: currency,
              label: Text(currency.code),
            ),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

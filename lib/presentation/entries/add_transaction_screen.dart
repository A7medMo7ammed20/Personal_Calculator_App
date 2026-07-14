import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/contact.dart';
import '../../domain/contact_sort.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contacts/add_contact_screen.dart';
import 'entry_fields.dart';

/// Home-first *Add معاملة* (#25): pick (or create) a contact inline, then book
/// an [Entry] against it in the active lens [currency] using the shared
/// [EntryFields]. Pops with the saved [Entry], or null if cancelled. The picker
/// lists only active contacts (archived ones are excluded by
/// [ContactRepository.list]).
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.contactRepository,
    required this.entryRepository,
    required this.currency,
  });

  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final Currency currency;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Contact> _all = const [];
  Contact? _selected;
  String _query = '';
  Direction _direction = Direction.owedToMe;
  late DateTime _when = nowToMinute();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final all = await widget.contactRepository.list();
    if (mounted) setState(() => _all = all);
  }

  Future<void> _pickDateTime() async {
    final picked = await pickEntryDateTime(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  /// No contact matched the typed name → create one on the spot, then select it.
  Future<void> _createContact(String name) async {
    final created = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(repository: widget.contactRepository),
      ),
    );
    if (created == null || !mounted) return;
    final all = await widget.contactRepository.list();
    if (!mounted) return;
    setState(() {
      _all = all;
      _selected = created;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_selected == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.contactRequired)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final description = _descriptionController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final saved = await widget.entryRepository.add(Entry(
      contactId: _selected!.id!,
      amount: amount,
      direction: _direction,
      currency: widget.currency,
      createdAt: _when,
      description: description.isEmpty ? null : description,
    ));
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addEntry)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('tx-contact-search'),
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.quickAddSearchHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 8),
            if (_selected == null)
              ..._contactResults(l10n)
            else
              _selectedRow(_selected!),
            const Divider(height: 24),
            EntryFields(
              amountController: _amountController,
              descriptionController: _descriptionController,
              direction: _direction,
              onDirectionChanged: (d) => setState(() => _direction = d),
              when: _when,
              onPickDateTime: _pickDateTime,
              amountAutofocus: false,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('tx-save'),
              onPressed: _saving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contactResults(AppLocalizations l10n) {
    final matches = filterContacts(_all, _query);
    final query = _query.trim();
    return [
      for (final c in matches)
        ListTile(
          key: Key('tx-contact-${c.id}'),
          leading: const Icon(Icons.person_outline),
          title: Text(c.name),
          subtitle: c.phone != null ? Text(c.phone!) : null,
          onTap: () => setState(() => _selected = c),
        ),
      // A name that matches nothing offers a one-tap create-and-select path.
      if (query.isNotEmpty && matches.isEmpty)
        ListTile(
          key: const Key('tx-create-contact'),
          leading: const Icon(Icons.person_add),
          title: Text(l10n.quickAddCreateContact(query)),
          onTap: () => _createContact(query),
        ),
    ];
  }

  Widget _selectedRow(Contact contact) {
    return ListTile(
      key: const Key('tx-selected-contact'),
      leading: const Icon(Icons.person),
      title: Text(contact.name),
      subtitle: contact.phone != null ? Text(contact.phone!) : null,
      trailing: IconButton(
        key: const Key('tx-clear-contact'),
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _selected = null),
      ),
    );
  }
}

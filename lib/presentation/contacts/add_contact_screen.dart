import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entries/entry_fields.dart';

/// Form to add a new [Contact] — or edit an existing one when [existing] is
/// passed. Name is required; phone is optional. Pops with the saved/updated
/// [Contact] on success, or null if cancelled.
///
/// When [entryRepository] and [currency] are supplied for a *new* contact, an
/// optional opening-معاملة section is shown (#25): if an amount is entered, the
/// contact's first [Entry] is booked in [currency] on save.
///
/// Caveat: clearing a phone on edit is out of scope this slice —
/// [Contact.copyWith] cannot set it back to null, so an emptied field retains
/// the prior phone.
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({
    super.key,
    required this.repository,
    this.existing,
    this.entryRepository,
    this.currency,
  });

  final ContactRepository repository;

  /// When non-null, the form edits this Contact's name/phone in place (#5).
  final Contact? existing;

  /// Books the optional opening معاملة. When null (or [currency] is null, or
  /// editing an existing contact) the opening-entry section is hidden.
  final EntryRepository? entryRepository;

  /// The active lens the opening معاملة is booked in.
  final Currency? currency;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  Direction _direction = Direction.owedToMe;
  late DateTime _when = nowToMinute();
  bool _saving = false;

  /// The opening-معاملة section shows only for a brand-new contact with the
  /// entry repository + lens wired in.
  bool get _showFirstEntry =>
      widget.entryRepository != null &&
      widget.currency != null &&
      widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickEntryDateTime(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final existing = widget.existing;

    final Contact result;
    if (existing != null) {
      result = existing.copyWith(name: name, phone: phone.isEmpty ? null : phone);
      await widget.repository.update(result);
    } else {
      result = await widget.repository.add(
        Contact(name: name, phone: phone.isEmpty ? null : phone),
      );
      // Optional opening معاملة (#25): book it only when the section is shown
      // and an amount was actually entered.
      final amountText = _amountController.text.trim();
      if (_showFirstEntry && amountText.isNotEmpty) {
        final description = _descriptionController.text.trim();
        await widget.entryRepository!.add(Entry(
          contactId: result.id!,
          amount: double.parse(amountText),
          direction: _direction,
          currency: widget.currency!,
          createdAt: _when,
          description: description.isEmpty ? null : description,
        ));
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.addContact : l10n.editContact),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('contact-name'),
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.contactName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.nameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.contactPhone,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_showFirstEntry) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.firstEntrySection,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  EntryFields(
                    amountController: _amountController,
                    descriptionController: _descriptionController,
                    direction: _direction,
                    onDirectionChanged: (d) => setState(() => _direction = d),
                    when: _when,
                    onPickDateTime: _pickDateTime,
                    amountAutofocus: false,
                    requireAmount: false,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('contact-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

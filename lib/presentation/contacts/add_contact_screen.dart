import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../domain/contact.dart';
import '../../l10n/gen/app_localizations.dart';

/// Form to add a new [Contact] — or edit an existing one when [existing] is
/// passed. Name is required; phone is optional. Pops with the saved/updated
/// [Contact] on success, or null if cancelled.
///
/// Caveat: clearing a phone on edit is out of scope this slice —
/// [Contact.copyWith] cannot set it back to null, so an emptied field retains
/// the prior phone.
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key, required this.repository, this.existing});

  final ContactRepository repository;

  /// When non-null, the form edits this Contact's name/phone in place (#5).
  final Contact? existing;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

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
    super.dispose();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/entry_repository.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';
import 'entry_fields.dart';

/// Form to add a new [Entry] under a Contact — or edit an existing one when
/// [existing] is passed: amount, direction, date/time and an optional
/// description. Pops with the saved/updated [Entry] on success, or null if
/// cancelled. The [currency] is inherited from the global lens — there is no
/// in-form currency picker (see CONTEXT.md).
///
/// Caveat: clearing a description on edit is out of scope this slice —
/// [Entry.copyWith] cannot set it back to null, so an emptied field retains the
/// prior description.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    super.key,
    required this.contactId,
    required this.repository,
    required this.currency,
    this.existing,
  });

  final int contactId;
  final EntryRepository repository;
  final Currency currency;

  /// When non-null, the form edits this Entry in place instead of adding a new
  /// one (issue #5). The currency lens is still inherited — never edited here.
  final Entry? existing;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Direction _direction;
  late DateTime _when;
  bool _saving = false;

  /// Renders 100.0 as "100" and 42.5 as "42.5" for the amount field.
  static String _trimAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toString();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = _trimAmount(existing.amount);
      _descriptionController.text = existing.description ?? '';
      _direction = existing.direction;
      _when = existing.createdAt;
    } else {
      _direction = Direction.owedToMe;
      _when = nowToMinute();
    }
  }

  @override
  void dispose() {
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
    final description = _descriptionController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final existing = widget.existing;

    final Entry result;
    if (existing != null) {
      result = existing.copyWith(
        amount: amount,
        direction: _direction,
        createdAt: _when,
        description: description.isEmpty ? null : description,
      );
      await widget.repository.update(result);
    } else {
      result = await widget.repository.add(Entry(
        contactId: widget.contactId,
        amount: amount,
        direction: _direction,
        currency: widget.currency,
        createdAt: _when,
        description: description.isEmpty ? null : description,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.addEntry : l10n.editEntry),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryFields(
                amountController: _amountController,
                descriptionController: _descriptionController,
                direction: _direction,
                onDirectionChanged: (d) => setState(() => _direction = d),
                when: _when,
                onPickDateTime: _pickDateTime,
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

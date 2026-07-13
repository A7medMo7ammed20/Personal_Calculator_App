import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/entry_repository.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';

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

  static DateTime _nowToMinute() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

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
      _when = _nowToMinute();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;

    setState(() {
      _when = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _when.hour,
        time?.minute ?? _when.minute,
      );
    });
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
    final scheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(_when);

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
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.entryAmount,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return l10n.amountRequired;
                  final amount = double.tryParse(text);
                  if (amount == null || amount <= 0) return l10n.amountInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<Direction>(
                segments: [
                  ButtonSegment(
                    value: Direction.owedToMe,
                    label: Text(l10n.directionOwedToMe),
                    icon: const Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: Direction.owedByMe,
                    label: Text(l10n.directionOwedByMe),
                    icon: const Icon(Icons.north_east),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) {
                  setState(() => _direction = selection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (!states.contains(WidgetState.selected)) return null;
                    return _direction == Direction.owedToMe
                        ? Colors.green.withValues(alpha: 0.18)
                        : scheme.errorContainer;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.event),
                label: Text('${l10n.entryDateTime}: $dateLabel'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.entryDescription,
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

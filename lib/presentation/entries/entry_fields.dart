import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/entry.dart';
import '../../l10n/gen/app_localizations.dart';
import 'amount_calculator_sheet.dart';

/// The shared body of every entry form (#25): amount + direction + date/time +
/// description. State (controllers, direction, [when]) is owned by the parent
/// screen so the same fields back the add-entry, quick-add-معاملة and
/// add-contact opening-entry flows without duplicating the widgets. Renders no
/// [Form] and no Save button — the parent supplies those.
class EntryFields extends StatelessWidget {
  const EntryFields({
    super.key,
    required this.amountController,
    required this.descriptionController,
    required this.direction,
    required this.onDirectionChanged,
    required this.when,
    required this.onPickDateTime,
    this.amountAutofocus = true,
    this.requireAmount = true,
  });

  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final Direction direction;
  final ValueChanged<Direction> onDirectionChanged;
  final DateTime when;
  final VoidCallback onPickDateTime;
  final bool amountAutofocus;

  /// When false an empty amount validates (the add-contact opening entry is
  /// optional). A non-empty but invalid amount is still rejected.
  final bool requireAmount;

  /// Opens the Amount calculator (ADR 0011), seeded from whatever the amount
  /// field currently holds, and writes the committed result back into it.
  /// Result-only: nothing but the number is placed in the box.
  Future<void> _openCalculator(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final seed = double.tryParse(amountController.text.trim());
    final result = await showAmountCalculator(context, seed: seed);
    if (result != null) amountController.text = result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(when);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('entry-amount'),
          controller: amountController,
          autofocus: amountAutofocus,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.entryAmount,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              key: const Key('entry-amount-calc'),
              icon: const Icon(Icons.calculate_outlined),
              tooltip: l10n.calculatorTooltip,
              onPressed: () => _openCalculator(context),
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return requireAmount ? l10n.amountRequired : null;
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
          selected: {direction},
          onSelectionChanged: (selection) {
            onDirectionChanged(selection.first);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (!states.contains(WidgetState.selected)) return null;
              return direction == Direction.owedToMe
                  ? Colors.green.withValues(alpha: 0.18)
                  : scheme.errorContainer;
            }),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onPickDateTime,
          icon: const Icon(Icons.event),
          label: Text('${l10n.entryDateTime}: $dateLabel'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descriptionController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.entryDescription,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// `DateTime.now()` truncated to the minute — the default timestamp seed for a
/// new entry. Shared so every entry flow seeds `when` identically.
DateTime nowToMinute() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
}

/// Runs the date-then-time picker seeded from [current] and returns the picked
/// `DateTime`, or null if the date picker was cancelled (or the context was
/// unmounted). A cancelled time picker keeps [current]'s hour/minute.
Future<DateTime?> pickEntryDateTime(BuildContext context, DateTime current) async {
  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (!context.mounted) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? current.hour,
    time?.minute ?? current.minute,
  );
}

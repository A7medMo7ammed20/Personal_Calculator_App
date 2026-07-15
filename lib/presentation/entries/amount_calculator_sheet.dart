import 'package:flutter/material.dart';

import '../../domain/calculator.dart';
import '../../l10n/gen/app_localizations.dart';

/// Shows the Amount calculator (CONTEXT.md, ADR 0011) as a modal bottom sheet,
/// seeded from the amount box's current [seed] value. Resolves to the trimmed
/// result string to drop into the amount box, or null if dismissed without
/// committing. Result-only — the expression itself is never returned or stored.
Future<String?> showAmountCalculator(BuildContext context, {double? seed}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AmountCalculatorSheet(seed: seed),
  );
}

class _AmountCalculatorSheet extends StatefulWidget {
  const _AmountCalculatorSheet({this.seed});

  final double? seed;

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  late Calculator _calc = Calculator.seed(widget.seed);

  void _apply(Calculator next) => setState(() => _calc = next);

  void _commit() {
    if (_calc.canCommit) Navigator.of(context).pop(_calc.commitText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // The numeric display and keypad stay LTR even under Arabic — a
        // calculator's number layout is universal (CONTEXT.md, Amount
        // calculator). Localized chrome (the Done label, the error message)
        // still renders correctly inside.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Display(calc: _calc, l10n: l10n),
              const SizedBox(height: 12),
              _Keypad(
                onDigit: (d) => _apply(_calc.digit(d)),
                onDecimal: () => _apply(_calc.decimal()),
                onOperator: (op) => _apply(_calc.operate(op)),
                onBackspace: () => _apply(_calc.backspace()),
                onClear: () => _apply(_calc.clear()),
                onEquals: () => _apply(_calc.equals()),
                onDone: _calc.canCommit ? _commit : null,
                doneLabel: l10n.calculatorDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two-line display: the expression being built, and beneath it a live
/// preview of the result — or the divide-by-zero message in the error colour.
class _Display extends StatelessWidget {
  const _Display({required this.calc, required this.l10n});

  final Calculator calc;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = calc.isDivideByZero;
    final preview = isError ? l10n.calculatorDivideByZero : calc.resultText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Text(
            key: const Key('calc-expression'),
            calc.expression,
            maxLines: 1,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          key: const Key('calc-result'),
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    required this.onDone,
    required this.doneLabel,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<CalcOp> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final VoidCallback? onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row([
          _util(context, 'clear', 'C', onClear),
          _util(context, 'backspace', '⌫', onBackspace),
          _operator('divide', CalcOp.divide),
          _operator('multiply', CalcOp.multiply),
        ]),
        _row([
          _digit('7'), _digit('8'), _digit('9'),
          _operator('subtract', CalcOp.subtract),
        ]),
        _row([
          _digit('4'), _digit('5'), _digit('6'),
          _operator('add', CalcOp.add),
        ]),
        _row([
          _digit('1'), _digit('2'), _digit('3'),
          _equals(context),
        ]),
        _row([
          _digit('0'), _decimal(),
          Expanded(flex: 2, child: _doneButton(context)),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 60,
          child: Row(children: children),
        ),
      );

  Widget _digit(String d) => Expanded(
        child: _CalcButton(
          buttonKey: Key('calc-key-$d'),
          label: d,
          onTap: () => onDigit(d),
        ),
      );

  Widget _decimal() => Expanded(
        child: _CalcButton(
          buttonKey: const Key('calc-decimal'),
          label: '.',
          onTap: onDecimal,
        ),
      );

  Widget _operator(String key, CalcOp op) => Expanded(
        child: _CalcButton(
          buttonKey: Key('calc-op-$key'),
          label: op.symbol,
          tone: _Tone.operator,
          onTap: () => onOperator(op),
        ),
      );

  Widget _util(
    BuildContext context,
    String key,
    String label,
    VoidCallback onTap,
  ) =>
      Expanded(
        child: _CalcButton(
          buttonKey: Key('calc-$key'),
          label: label,
          tone: _Tone.util,
          onTap: onTap,
        ),
      );

  Widget _equals(BuildContext context) => Expanded(
        child: _CalcButton(
          buttonKey: const Key('calc-equals'),
          label: '=',
          tone: _Tone.operator,
          onTap: onEquals,
        ),
      );

  Widget _doneButton(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: FilledButton(
          key: const Key('calc-done'),
          onPressed: onDone,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(double.infinity),
          ),
          child: Text(doneLabel),
        ),
      );
}

enum _Tone { digit, operator, util }

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
    this.tone = _Tone.digit,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onTap;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _Tone.digit => (scheme.surfaceContainerHighest, scheme.onSurface),
      _Tone.operator => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _Tone.util => (scheme.surfaceContainer, scheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        key: buttonKey,
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

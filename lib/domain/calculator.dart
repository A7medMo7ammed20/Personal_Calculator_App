/// The Amount calculator's pure engine (see CONTEXT.md, ADR 0011). A keypad
/// computes an [Entry] amount with `+ − × ÷`; the rounded result is placed in
/// the amount box. Pure Dart, no Flutter dependency, so the arithmetic and the
/// keypad state machine stay unit-testable without the UI.
///
/// The engine is immutable: every keypad action returns a new [Calculator].
/// Illegal states are unreachable by construction — the token list always starts
/// with a number and alternates number/operator, so there are never two
/// operators in a row or two decimal points in one number. Division by zero is
/// the single guarded runtime case.
library;

/// A binary operator on the keypad. [symbol] is the glyph shown in the
/// expression and on the button (`−` is U+2212, not a hyphen).
enum CalcOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CalcOp(this.symbol);

  final String symbol;
}

sealed class _Token {
  const _Token();
}

/// A number being built up, kept as its typed text (e.g. `"1500"`, `"3."`,
/// `"0"`) so partial input like a lone trailing dot round-trips on the display.
class _Num extends _Token {
  const _Num(this.text);
  final String text;
}

class _OpTok extends _Token {
  const _OpTok(this.op);
  final CalcOp op;
}

class Calculator {
  const Calculator._(this._tokens);

  /// A fresh calculator showing `0`.
  factory Calculator.empty() => const Calculator._([_Num('0')]);

  /// Seeds the calculator from the amount box's current [value] so it can be
  /// adjusted (e.g. bumping an existing entry). A null or non-positive value —
  /// an empty or invalid field — starts fresh at `0`. The seed is trimmed to
  /// money precision.
  factory Calculator.seed(double? value) {
    if (value == null || value <= 0) return Calculator.empty();
    return Calculator._([_Num(_format(value))]);
  }

  final List<_Token> _tokens;

  _Token get _last => _tokens.last;

  List<_Token> get _copy => List<_Token>.of(_tokens);

  /// Appends a digit `0`–`9` to the current operand (or starts a new operand
  /// after an operator). A leading `0` is replaced rather than kept.
  Calculator digit(String d) {
    final tokens = _copy;
    final last = _last;
    if (last is _OpTok) {
      tokens.add(_Num(d));
    } else if (last is _Num) {
      final text = last.text == '0' ? (d == '0' ? '0' : d) : last.text + d;
      tokens[tokens.length - 1] = _Num(text);
    }
    return Calculator._(tokens);
  }

  /// Adds a decimal point to the current operand. Ignored if the operand
  /// already has one; starts `0.` when the previous token is an operator.
  Calculator decimal() {
    final tokens = _copy;
    final last = _last;
    if (last is _OpTok) {
      tokens.add(const _Num('0.'));
    } else if (last is _Num) {
      if (last.text.contains('.')) return this;
      tokens[tokens.length - 1] = _Num('${last.text}.');
    }
    return Calculator._(tokens);
  }

  /// Applies an operator. A trailing operator is *replaced* (never doubled), so
  /// `5 + ×` becomes `5 ×`.
  Calculator operate(CalcOp op) {
    final tokens = _copy;
    final last = _last;
    if (last is _OpTok) {
      tokens[tokens.length - 1] = _OpTok(op);
    } else if (last is _Num) {
      // Normalise a bare trailing dot ("3." -> "3") before the operator.
      if (last.text.endsWith('.')) {
        tokens[tokens.length - 1] =
            _Num(last.text.substring(0, last.text.length - 1));
      }
      tokens.add(_OpTok(op));
    }
    return Calculator._(tokens);
  }

  /// Deletes the last keystroke: drops a trailing operator, or a character from
  /// the current operand. Emptying the only operand resets it to `0`.
  Calculator backspace() {
    final tokens = _copy;
    final last = _last;
    if (last is _OpTok) {
      tokens.removeLast();
    } else if (last is _Num) {
      if (last.text.length > 1) {
        tokens[tokens.length - 1] =
            _Num(last.text.substring(0, last.text.length - 1));
      } else if (tokens.length == 1) {
        tokens[0] = const _Num('0');
      } else {
        tokens.removeLast(); // exposes the preceding (dangling) operator
      }
    }
    return Calculator._(tokens);
  }

  /// Clears back to `0`.
  Calculator clear() => Calculator.empty();

  /// Evaluates and collapses the expression to its rounded result, so the user
  /// can keep operating on it. A no-op on divide-by-zero (nothing to collapse).
  Calculator equals() {
    final value = _evaluate();
    if (value == null) return this;
    return Calculator._([_Num(_format(value))]);
  }

  /// The expression as shown to the user, e.g. `"1500 + 300"` or, mid-entry,
  /// `"1500 +"`.
  String get expression => _tokens
      .map((t) => switch (t) {
            _Num(:final text) => text,
            _OpTok(:final op) => op.symbol,
          })
      .join(' ');

  /// True when the completed expression divides by zero.
  bool get isDivideByZero => _evaluate() == null;

  /// Whether the current result is a positive amount that can be committed to
  /// the amount box: no divide-by-zero, no dangling operator, and `> 0` after
  /// rounding to 2 decimals.
  bool get canCommit {
    if (_last is _OpTok) return false;
    final value = _evaluate();
    if (value == null) return false;
    return _round(value) > 0;
  }

  /// The rounded result as a trimmed string (`"2000"`, `"3.33"`, `"2.5"`), or
  /// empty on divide-by-zero.
  String get resultText {
    final value = _evaluate();
    if (value == null) return '';
    return _format(value);
  }

  /// The text to drop into the amount box — the rounded result — valid only
  /// when [canCommit].
  String get commitText => resultText;

  /// Evaluates the completed part of the expression (a dangling trailing
  /// operator is ignored) with `× ÷` bound tighter than `+ −`. Returns null on
  /// division by zero.
  double? _evaluate() {
    final operands = <double>[];
    final ops = <CalcOp>[];
    for (final t in _tokens) {
      switch (t) {
        case _Num(:final text):
          operands.add(_parse(text));
        case _OpTok(:final op):
          ops.add(op);
      }
    }
    // Drop a dangling operator with no right-hand operand.
    if (ops.length >= operands.length) ops.removeLast();

    // Pass 1: fold × and ÷ into their neighbours.
    final nums = <double>[operands.first];
    final addOps = <CalcOp>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final rhs = operands[i + 1];
      switch (op) {
        case CalcOp.multiply:
          nums[nums.length - 1] *= rhs;
        case CalcOp.divide:
          if (rhs == 0) return null;
          nums[nums.length - 1] /= rhs;
        case CalcOp.add:
        case CalcOp.subtract:
          addOps.add(op);
          nums.add(rhs);
      }
    }

    // Pass 2: apply + and −.
    var result = nums.first;
    for (var j = 0; j < addOps.length; j++) {
      result += addOps[j] == CalcOp.add ? nums[j + 1] : -nums[j + 1];
    }
    return result;
  }

  /// Parses a possibly-partial operand string (`"3."`, `"0"`) to a double.
  static double _parse(String text) {
    final trimmed = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    return double.tryParse(trimmed) ?? 0;
  }

  /// Rounds to the currency's 2 decimals (money is 2-decimal everywhere).
  static double _round(double v) => double.parse(v.toStringAsFixed(2));

  /// Rounds to 2 decimals and trims trailing zeros, matching the amount
  /// field's convention (`2.50 -> 2.5`, `1800.00 -> 1800`).
  static String _format(double v) {
    var s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}

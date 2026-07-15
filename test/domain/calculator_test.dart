import 'package:debt_ledger/domain/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types a run of keys into [c]. Digits and '.' feed the current number;
/// `+ - * /` map to the four operators. Keeps the tests readable.
Calculator type(Calculator c, String keys) {
  for (final ch in keys.split('')) {
    c = switch (ch) {
      '+' => c.operate(CalcOp.add),
      '-' => c.operate(CalcOp.subtract),
      '*' => c.operate(CalcOp.multiply),
      '/' => c.operate(CalcOp.divide),
      '.' => c.decimal(),
      ' ' => c, // ignore spacing in the test literal
      _ => c.digit(ch),
    };
  }
  return c;
}

void main() {
  group('evaluation', () {
    test('adds a chain of operands left to right', () {
      final c = type(Calculator.empty(), '1500+300+200');
      expect(c.expression, '1500 + 300 + 200');
      expect(c.resultText, '2000');
    });

    test('honours operator precedence — × before +', () {
      final c = type(Calculator.empty(), '2+3*4');
      expect(c.expression, '2 + 3 × 4');
      expect(c.resultText, '14');
    });

    test('honours operator precedence — ÷ before −', () {
      final c = type(Calculator.empty(), '100-20/4');
      expect(c.resultText, '95');
    });

    test('renders exact division without spurious decimals', () {
      final c = type(Calculator.empty(), '10/4');
      expect(c.resultText, '2.5');
    });
  });

  group('rounding to 2 decimals', () {
    test('rounds a repeating division to 2 places', () {
      final c = type(Calculator.empty(), '10/3');
      expect(c.resultText, '3.33');
    });

    test('rounds half up at the cent', () {
      final c = type(Calculator.empty(), '100/7'); // 14.2857…
      expect(c.resultText, '14.29');
    });

    test('trims a trailing zero left by rounding', () {
      final c = type(Calculator.empty(), '10/4'); // 2.50 -> 2.5
      expect(c.resultText, '2.5');
    });
  });

  group('divide by zero', () {
    test('flags division by zero and refuses a result', () {
      final c = type(Calculator.empty(), '5/0');
      expect(c.isDivideByZero, isTrue);
      expect(c.canCommit, isFalse);
    });

    test('recovers once the zero divisor is edited away', () {
      final c = type(Calculator.empty(), '5/0');
      final fixed = type(c.backspace(), '2'); // 5 / 2
      expect(fixed.isDivideByZero, isFalse);
      expect(fixed.resultText, '2.5');
      expect(fixed.canCommit, isTrue);
    });
  });

  group('seeding from the amount box', () {
    test('seeds an existing amount so it can be extended', () {
      final c = type(Calculator.seed(500), '+50');
      expect(c.expression, '500 + 50');
      expect(c.resultText, '550');
    });

    test('seeds an empty or invalid field as zero', () {
      final c = Calculator.seed(null);
      expect(c.expression, '0');
      expect(c.canCommit, isFalse);
    });

    test('trims a seeded value to money precision', () {
      final c = Calculator.seed(42.5);
      expect(c.expression, '42.5');
      expect(c.resultText, '42.5');
      expect(c.canCommit, isTrue);
    });
  });

  group('equals', () {
    test('collapses the expression to its rounded result', () {
      final c = type(Calculator.empty(), '10/3').equals();
      expect(c.expression, '3.33');
      expect(c.resultText, '3.33');
    });

    test('keeps operating on an equals result', () {
      final c = type(type(Calculator.empty(), '10/3').equals(), '*3');
      expect(c.expression, '3.33 × 3');
      expect(c.resultText, '9.99');
    });

    test('is a no-op on divide by zero', () {
      final c = type(Calculator.empty(), '5/0').equals();
      expect(c.isDivideByZero, isTrue);
      expect(c.expression, '5 ÷ 0');
    });
  });

  group('keypad rules — illegal states unreachable', () {
    test('a new operator replaces a trailing operator', () {
      final c = type(Calculator.empty(), '5+*3'); // + then × replaces +
      expect(c.expression, '5 × 3');
      expect(c.resultText, '15');
    });

    test('only one decimal point per operand', () {
      final c = type(Calculator.empty(), '3..5');
      expect(c.expression, '3.5');
    });

    test('a leading zero is replaced by the first digit', () {
      expect(type(Calculator.empty(), '05').expression, '5');
    });

    test('keeps the zero when building a decimal', () {
      expect(type(Calculator.empty(), '0.5').expression, '0.5');
    });

    test('clear resets to zero', () {
      final c = type(Calculator.empty(), '123+45').clear();
      expect(c.expression, '0');
      expect(c.canCommit, isFalse);
    });

    test('backspace drops a dangling operator, then digits', () {
      final c = type(Calculator.empty(), '12+');
      expect(c.backspace().expression, '12');
      expect(c.backspace().backspace().expression, '1');
    });
  });

  group('commit gating', () {
    test('a dangling operator shows the completed result but blocks commit', () {
      final c = type(Calculator.empty(), '1500+');
      expect(c.expression, '1500 +');
      expect(c.resultText, '1500');
      expect(c.canCommit, isFalse);
    });

    test('a zero result cannot be committed', () {
      final c = type(Calculator.empty(), '5-5');
      expect(c.resultText, '0');
      expect(c.canCommit, isFalse);
    });

    test('a negative result cannot be committed', () {
      final c = type(Calculator.empty(), '5-8');
      expect(c.resultText, '-3');
      expect(c.canCommit, isFalse);
    });

    test('commitText is the rounded result when committable', () {
      final c = type(Calculator.empty(), '1500+300');
      expect(c.canCommit, isTrue);
      expect(c.commitText, '1800');
    });
  });
}

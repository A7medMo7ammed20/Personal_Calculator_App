import 'package:debt_ledger/branding/daftar_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the splash skips to done immediately', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 100)); // mid-animation
    await tester.tap(find.byType(DaftarSplash));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('completes on its own within ~1s', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 700)); // draw
    await tester.pump(const Duration(milliseconds: 350)); // hold
    expect(done, 1);
  });

  testWidgets('never calls onDone twice (tap then auto-complete)', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: DaftarSplash(onDone: () => done++)));
    await tester.tap(find.byType(DaftarSplash));
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });
}

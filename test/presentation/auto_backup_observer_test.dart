import 'package:debt_ledger/data/backup_dirty_flag.dart';
import 'package:debt_ledger/presentation/backup/auto_backup_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('snapshots on paused only when dirty, once per dirty span', (
    tester,
  ) async {
    final dirty = BackupDirtyFlag();
    var calls = 0;

    await tester.pumpWidget(AutoBackupObserver(
      dirtyFlag: dirty,
      onBackground: () async => calls++,
      child: const SizedBox(),
    ));

    // Clean → paused does nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 0);

    // Dirty → paused snapshots once and clears the flag.
    dirty.mark();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 1);
    expect(dirty.isDirty, isFalse);

    // Backgrounding again without a new write does nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls, 1);
  });
}

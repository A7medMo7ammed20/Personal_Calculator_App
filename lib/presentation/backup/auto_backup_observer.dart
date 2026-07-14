import 'package:flutter/material.dart';

import '../../data/backup_dirty_flag.dart';

/// Fires [onBackground] when the app is backgrounded (`AppLifecycleState.paused`
/// — reliably delivered, unlike `detached`) and only if [dirtyFlag] is set, then
/// clears the flag. This is the auto-backup trigger (ADR 0010): no snapshot when
/// nothing changed since the last one (story #19).
class AutoBackupObserver extends StatefulWidget {
  const AutoBackupObserver({
    super.key,
    required this.dirtyFlag,
    required this.onBackground,
    required this.child,
  });

  final BackupDirtyFlag dirtyFlag;
  final Future<void> Function() onBackground;
  final Widget child;

  @override
  State<AutoBackupObserver> createState() => _AutoBackupObserverState();
}

class _AutoBackupObserverState extends State<AutoBackupObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.dirtyFlag.isDirty) {
      widget.dirtyFlag.reset();
      widget.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

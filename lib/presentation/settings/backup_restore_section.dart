import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/backup_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme/theme_context.dart';

/// Everything the Settings "Backup & restore" section needs. Platform hand-off
/// (share sheet / file picker) lives behind [onShare] / [onPickFile] so widget
/// tests never touch platform channels (mirrors the `onSharePdf` seam). A
/// successful restore calls [onRestored] (the app's reload helper); all outcomes
/// surface via [showMessage] (a root-messenger snackbar that survives remount).
class BackupSectionConfig {
  const BackupSectionConfig({
    required this.service,
    required this.onShare,
    required this.onPickFile,
    required this.onRestored,
    required this.showMessage,
  });

  final BackupService service;
  final Future<void> Function(File file) onShare;
  final Future<File?> Function() onPickFile;
  final Future<void> Function() onRestored;
  final void Function(String message) showMessage;
}

/// The Backup & restore Settings section (ADR 0010): Export, Restore-from-file,
/// Restore-from-auto-backup. Full-replace restore is gated by a single confirm
/// dialog (NOT the type-to-confirm reserved for Erase all data).
class BackupRestoreSection extends StatelessWidget {
  const BackupRestoreSection({super.key, required this.config});

  final BackupSectionConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsBackup,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        SizedBox(height: context.spacing.sm),
        ListTile(
          key: const Key('backup-export'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.ios_share),
          title: Text(l10n.backupExport),
          subtitle: Text(l10n.backupExportHint),
          onTap: () => _export(context, l10n),
        ),
        ListTile(
          key: const Key('backup-restore-file'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore_page),
          title: Text(l10n.backupRestoreFromFile),
          onTap: () => _restoreFromFile(context, l10n),
        ),
        ListTile(
          key: const Key('backup-restore-auto'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(l10n.backupRestoreFromAuto),
          onTap: () => _restoreFromAuto(context, l10n),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, AppLocalizations l10n) async {
    try {
      final file = await config.service.export();
      await config.onShare(file);
      config.showMessage(l10n.exportSuccess);
    } catch (_) {
      config.showMessage(l10n.exportFailed);
    }
  }

  Future<void> _restoreFromFile(BuildContext context, AppLocalizations l10n) async {
    if (!await _confirm(context, l10n)) return;
    final file = await config.onPickFile();
    if (file == null) return; // user cancelled the picker
    await _runRestore(l10n, file);
  }

  Future<void> _restoreFromAuto(BuildContext context, AppLocalizations l10n) async {
    final ring = await config.service.listAutoBackups();
    if (!context.mounted) return;
    if (ring.isEmpty) {
      config.showMessage(l10n.backupNoAutoBackups);
      return;
    }
    final picked = await showDialog<AutoBackupEntry>(
      context: context,
      builder: (context) {
        final fmt = DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .add_jm();
        return AlertDialog(
          title: Text(l10n.backupAutoBackupsTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < ring.length; i++)
                  ListTile(
                    key: Key('auto-backup-$i'),
                    title: Text(fmt.format(ring[i].createdAt)),
                    onTap: () => Navigator.of(context).pop(ring[i]),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    if (picked == null || !context.mounted) return;
    if (!await _confirm(context, l10n)) return;
    await _runRestore(l10n, picked.file);
  }

  Future<bool> _confirm(BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreTitle),
        content: Text(l10n.backupRestoreMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('backup-restore-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runRestore(AppLocalizations l10n, File file) async {
    final RestoreResult result;
    try {
      result = await config.service.restore(file);
    } catch (_) {
      config.showMessage(l10n.restoreFailed);
      return;
    }
    switch (result) {
      case RestoreResult.success:
        await config.onRestored();
        config.showMessage(l10n.restoreSuccess);
      case RestoreResult.notABackup:
        config.showMessage(l10n.restoreNotABackup);
      case RestoreResult.newerVersion:
        config.showMessage(l10n.restoreNewerVersion);
      case RestoreResult.failure:
        config.showMessage(l10n.restoreFailed);
    }
  }
}

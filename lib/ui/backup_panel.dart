import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/ledger.dart';
import '../data/ledger_snapshot.dart';
import 'design.dart';

enum _BackupAction { export, restore, confirmRestore }

class BackupPanel extends StatefulWidget {
  const BackupPanel({super.key});

  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  _BackupAction? _busy;

  Future<void> _export(Ledger ledger) async {
    if (_busy != null) return;
    setState(() => _busy = _BackupAction.export);
    try {
      final timestamp = ledger.now.toIso8601String().substring(0, 19);
      final name = 'tally-backup-${timestamp.replaceAll(':', '-')}.json';
      final saved = await FilePicker.saveFile(
        fileName: name,
        mimeType: 'application/json',
        dialogTitle: 'Save Tally backup',
        bytes: ledger.exportBackup(),
      );
      if (mounted && saved != null) feedback(context, 'Backup exported');
    } catch (_) {
      if (mounted) feedback(context, 'Couldn’t export the backup. Try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _restore(Ledger ledger) async {
    if (_busy != null) return;
    setState(() => _busy = _BackupAction.restore);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a Tally backup',
      );
      if (file == null || !mounted) return;
      final backup = LedgerSnapshot.fromBackup(await file.readAsBytes());
      if (!mounted) return;

      String count(int number, String name) =>
          '$number $name${number == 1 ? '' : 's'}';
      final summary = [
        count(backup.accounts.length, 'account'),
        count(backup.entries.length, 'transaction'),
        count(backup.budgets.length, 'budget'),
      ].join(' · ');
      setState(() => _busy = _BackupAction.confirmRestore);
      final confirmed = await confirmAction(
        context,
        title: 'Restore this backup?',
        message: '$summary\n\nThis will replace the ledger on this device.',
        action: 'Restore backup',
      );
      if (!confirmed || !mounted) return;
      setState(() => _busy = _BackupAction.restore);
      await ledger.restoreBackup(backup);
      if (mounted) feedback(context, 'Backup restored');
    } on FormatException catch (error) {
      if (mounted) feedback(context, error.message);
    } on LedgerException catch (error) {
      if (mounted) feedback(context, error.message);
    } catch (_) {
      if (mounted) {
        feedback(context, 'Couldn’t read the backup file. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    return Column(
      children: [
        const SectionTitle('Backup & restore'),
        Surface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _tile(
                context,
                action: _BackupAction.export,
                icon: Icons.file_download_outlined,
                title: 'Export backup',
                subtitle: 'Save a JSON copy of your ledger',
                onTap: () => _export(ledger),
              ),
              const Divider(height: 1, indent: 15, endIndent: 15),
              _tile(
                context,
                action: _BackupAction.restore,
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore backup',
                subtitle: 'Load a saved Tally backup',
                onTap: () => _restore(ledger),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required _BackupAction action,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    enabled: _busy == null,
    onTap: onTap,
    leading: Glyph(
      icon,
      Theme.of(context).colorScheme.primary,
      size: 34,
      iconSize: 18,
    ),
    title: Text(title, style: textStyle(14, weight: FontWeight.w700)),
    subtitle: Text(subtitle, style: textStyle(12, color: Palette.secondary)),
    trailing: _busy == action
        ? SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: title,
            ),
          )
        : const Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: Palette.muted,
          ),
  );
}

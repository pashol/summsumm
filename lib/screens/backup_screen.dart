import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/providers/backup_progress_provider.dart';
import 'package:summsumm/providers/backup_service_provider.dart';
import 'package:summsumm/services/backup_service.dart';
import 'package:summsumm/widgets/glass_card.dart';

enum _BackupMode { share, saveToDevice }

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _includeSettings = true;
  bool _includeApiKeys = false;
  bool _includeMeetings = true;
  bool _includeAudio = false;
  final _filenameCtrl = TextEditingController();
  bool _isImporting = false;
  ImportResult? _lastImportResult;
  _BackupMode _backupMode = _BackupMode.share;

  @override
  void initState() {
    super.initState();
    _filenameCtrl.text = _defaultFilename();
  }

  String _defaultFilename() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_backup';
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.backupNotificationPermission)),
        );
      }
      return;
    }

    final password = await _showPasswordDialog(isExport: true);
    if (password == null || password.isEmpty) return;

    ref.read(backupProgressProvider.notifier).startExport(
          password: password,
          includeSettings: _includeSettings,
          includeApiKeys: _includeApiKeys && _includeSettings,
          includeMeetings: _includeMeetings,
          includeAudio: _includeAudio && _includeMeetings,
          filename: _filenameCtrl.text,
          saveToDevice: _backupMode == _BackupMode.saveToDevice,
        );
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) return;

    final password = await _showPasswordDialog(isExport: false);
    if (password == null || password.isEmpty) return;

    setState(() {
      _isImporting = true;
      _lastImportResult = null;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final file = File(result.files.single.path!);

      final importResult = await service.import(
        password: password,
        file: file,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);

        setState(() => _lastImportResult = importResult);
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.backupImportedMeetings(
                importResult.meetingsImported,
                importResult.meetingsSkipped,
              ),),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.backupImportFailed(importResult.error ?? '')),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupImportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<String?> _showPasswordDialog({required bool isExport}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ctrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExport ? l10n.backupSetPassword : l10n.backupEnterPassword),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.backupPasswordLabel,
            hintText: l10n.backupPasswordHint,
          ),
          onSubmitted: (v) {
            if (v.length >= 8) {
              Navigator.pop(context, v);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text;
              if (text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.backupPasswordTooShort),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, text);
            },
            child: Text(isExport ? l10n.backupExportButton : l10n.backupEnterPassword.split(' ').first),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final backupProgress = ref.watch(backupProgressProvider);
    final isExporting = backupProgress.status == BackupStatus.running;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupTitle),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        children: [
          Semantics(
            container: true,
            label: l10n.backupExportTitle,
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.backup_outlined,
                            size: 18,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.backupExportTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (backupProgress.status == BackupStatus.running) ...[
                      LinearProgressIndicator(value: backupProgress.progress),
                      const SizedBox(height: 8),
                      Text(
                        l10n.backupRunning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (backupProgress.status == BackupStatus.completed) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: cs.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _backupMode == _BackupMode.saveToDevice
                                    ? l10n.backupSavedToDownloads
                                    : l10n.backupExportButton,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(backupProgressProvider.notifier).reset();
                              },
                              child: Text(l10n.backupDismiss),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (backupProgress.status == BackupStatus.failed) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: cs.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                backupProgress.error ?? l10n.backupSaveFailed,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.error,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(backupProgressProvider.notifier).reset();
                              },
                              child: Text(l10n.backupDismiss),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (backupProgress.status == BackupStatus.idle) ...[
                      Semantics(
                        container: true,
                        child: CheckboxListTile(
                          title: Text(l10n.backupIncludeSettings),
                          value: _includeSettings,
                          onChanged: (v) => setState(() => _includeSettings = v ?? true),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Semantics(
                        container: true,
                        child: CheckboxListTile(
                          title: Text(l10n.backupIncludeApiKeys),
                          subtitle: Text(l10n.backupIncludeApiKeysHint),
                          value: _includeApiKeys && _includeSettings,
                          onChanged: _includeSettings
                              ? (v) => setState(() => _includeApiKeys = v ?? false)
                              : null,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Semantics(
                        container: true,
                        child: CheckboxListTile(
                          title: Text(l10n.backupIncludeMeetings),
                          value: _includeMeetings,
                          onChanged: (v) => setState(() => _includeMeetings = v ?? true),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Semantics(
                        container: true,
                        child: CheckboxListTile(
                          title: Text(l10n.backupIncludeAudio),
                          subtitle: Text(l10n.backupIncludeAudioHint),
                          value: _includeAudio && _includeMeetings,
                          onChanged: _includeMeetings
                              ? (v) => setState(() => _includeAudio = v ?? false)
                              : null,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _filenameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.backupFilename,
                          border: const OutlineInputBorder(),
                          suffixText: '.summsumm',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.backupModeLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<_BackupMode>(
                        segments: [
                          ButtonSegment(
                            value: _BackupMode.share,
                            label: Text(l10n.backupModeShare),
                            icon: const Icon(Icons.share, size: 18),
                          ),
                          ButtonSegment(
                            value: _BackupMode.saveToDevice,
                            label: Text(l10n.backupModeSave),
                            icon: const Icon(Icons.save, size: 18),
                          ),
                        ],
                        selected: {_backupMode},
                        onSelectionChanged: (Set<_BackupMode> selection) {
                          setState(() => _backupMode = selection.first);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isExporting ? null : _export,
                        icon: isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: Text(
                          backupProgress.status == BackupStatus.running
                              ? l10n.backupRunning
                              : l10n.backupExportButton,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Semantics(
            container: true,
            label: l10n.backupImportTitle,
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.restore_outlined,
                            size: 18,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.backupImportTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.backupImportHint,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isImporting ? null : _import,
                        icon: _isImporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(l10n.backupSelectFile),
                      ),
                    ),
                    if (_lastImportResult != null && _lastImportResult!.success) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.backupImportSuccess,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.backupMeetingsImported(_lastImportResult!.meetingsImported)}\n'
                                '${l10n.backupMeetingsSkipped(_lastImportResult!.meetingsSkipped)}\n'
                                '${l10n.backupSettingsRestored(_lastImportResult!.settingsImported ? l10n.backupYes : l10n.backupNo)}\n'
                                '${l10n.backupApiKeysRestored(_lastImportResult!.apiKeysImported ? l10n.backupYes : l10n.backupNo)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
           ),
         ],
       ),
     );
   }
 }

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/providers/backup_service_provider.dart';
import 'package:summsumm/services/backup_service.dart';
import 'package:summsumm/widgets/glass_card.dart';

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
  bool _isExporting = false;
  bool _isImporting = false;
  ImportResult? _lastImportResult;

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
    final password = await _showPasswordDialog(isExport: true);
    if (password == null || password.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final service = ref.read(backupServiceProvider);
      final tempDir = await getTemporaryDirectory();
      
      final file = await service.export(
        password: password,
        includeSettings: _includeSettings,
        includeApiKeys: _includeApiKeys && _includeSettings,
        includeMeetings: _includeMeetings,
        includeAudio: _includeAudio && _includeMeetings,
        filename: _filenameCtrl.text,
        outputDir: tempDir.path,
      );

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Summsumm Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupExportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isExporting ? null : _export,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: Text(l10n.backupExportButton),
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
                      Container(
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

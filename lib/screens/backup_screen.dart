import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    return 'summsumm_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final password = await _showPasswordDialog(context, isExport: true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['summsumm'],
    );
    if (result == null || result.files.single.path == null) return;

    final password = await _showPasswordDialog(context, isExport: false);
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
        setState(() => _lastImportResult = importResult);
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${importResult.meetingsImported} meetings, '
                'skipped ${importResult.meetingsSkipped} duplicates.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Import failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context, {required bool isExport}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExport ? 'Set Backup Password' : 'Enter Backup Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Min 8 characters',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(isExport ? 'Export' : 'Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export Section
          GlassCard(
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
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.backup_outlined,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Export Backup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include settings'),
                    value: _includeSettings,
                    onChanged: (v) => setState(() => _includeSettings = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include API keys'),
                    subtitle: const Text('Requires settings to be included'),
                    value: _includeApiKeys && _includeSettings,
                    onChanged: _includeSettings
                        ? (v) => setState(() => _includeApiKeys = v ?? false)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include meeting data'),
                    value: _includeMeetings,
                    onChanged: (v) => setState(() => _includeMeetings = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include audio files'),
                    subtitle: const Text('Significantly increases file size'),
                    value: _includeAudio && _includeMeetings,
                    onChanged: _includeMeetings
                        ? (v) => setState(() => _includeAudio = v ?? false)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _filenameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filename',
                      border: OutlineInputBorder(),
                      suffixText: '.summsumm',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _export,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Import Section
          GlassCard(
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
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.restore_outlined,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Restore Backup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select a .summsumm backup file to restore your data. '
                    'Existing meetings will be skipped (not overwritten).',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isImporting ? null : _import,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Select Backup File'),
                    ),
                  ),
                  if (_lastImportResult != null && _lastImportResult!.success) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import successful',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meetings imported: ${_lastImportResult!.meetingsImported}\n'
                            'Meetings skipped: ${_lastImportResult!.meetingsSkipped}\n'
                            'Settings restored: ${_lastImportResult!.settingsImported ? "Yes" : "No"}\n'
                            'API keys restored: ${_lastImportResult!.apiKeysImported ? "Yes" : "No"}',
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
        ],
      ),
    );
  }
}

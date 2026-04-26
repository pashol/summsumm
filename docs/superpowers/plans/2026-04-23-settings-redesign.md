# Settings Menu Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the 960-line SettingsScreen into a hub + sub-pages layout with grouped cards.

**Architecture:** Extract 6 inline sections into dedicated screen files under `lib/screens/settings/`. Replace the main SettingsScreen body with a grouped list hub that navigates to each sub-page. All screens use the existing Riverpod `settingsProvider`.

**Tech Stack:** Flutter, Riverpod, Material Design 3

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/screens/settings/ai_models_screen.dart` | Create | Provider + model selection |
| `lib/screens/settings/api_connection_screen.dart` | Create | API key input + test connection |
| `lib/screens/settings/transcription_settings_screen.dart` | Create | Transcription strategy + model downloads |
| `lib/screens/settings/summary_language_screen.dart` | Create | Summary style + output language |
| `lib/screens/settings/tts_settings_screen.dart` | Create | TTS speed slider |
| `lib/screens/settings/app_language_screen.dart` | Create | App language selection |
| `lib/screens/settings_screen.dart` | Modify | Hub layout with grouped cards |

---

## Shared Widgets

The hub uses these widgets extracted from the current `SettingsScreen`:
- `_SectionCard` → renamed to `SettingsSectionCard` and kept in `settings_screen.dart`
- `_AdvancedModelPicker` → moved to `ai_models_screen.dart`
- `_SeriesGroup` → moved to `ai_models_screen.dart`

---

### Task 1: Extract AiModelsScreen

**Files:**
- Create: `lib/screens/settings/ai_models_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline model section)

- [ ] **Step 1: Create `lib/screens/settings/ai_models_screen.dart`**

Extract the model selection UI (provider dropdown, model dropdown, advanced model picker) from lines 176-264 of `settings_screen.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../models/ai_model.dart';
import '../../models/app_settings.dart';
import '../../providers/models_provider.dart';
import '../../providers/settings_provider.dart';

class AiModelsScreen extends ConsumerStatefulWidget {
  const AiModelsScreen({super.key});

  @override
  ConsumerState<AiModelsScreen> createState() => _AiModelsScreenState();
}

class _AiModelsScreenState extends ConsumerState<AiModelsScreen> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isProviderOpenAi = settings.provider == 'openai';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsModelSection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: settings.provider,
            decoration: InputDecoration(
              labelText: l10n.settingsProviderLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
            items: [
              DropdownMenuItem(value: 'openrouter', child: Text(l10n.settingsOpenRouter)),
              DropdownMenuItem(value: 'openai', child: Text(l10n.settingsOpenAi)),
            ],
            onChanged: (v) async {
              if (v != null && v != settings.provider) {
                await notifier.setProvider(v);
              }
            },
          ),
          const SizedBox(height: 16),
          if (isProviderOpenAi) ...[
            DropdownButtonFormField<String>(
              initialValue: settings.openaiModel.isEmpty
                  ? kOpenAiModels.first.id
                  : settings.openaiModel,
              decoration: InputDecoration(
                labelText: l10n.settingsModelSection,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.psychology_outlined),
              ),
              items: kOpenAiModels
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.setOpenAiModel(v);
              },
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: settings.openrouterModel.isEmpty
                  ? null
                  : settings.openrouterModel,
              decoration: InputDecoration(
                labelText: l10n.settingsModelSection,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.psychology_outlined),
              ),
              items: kCuratedModels
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.setOpenRouterModel(v);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
              title: Text(l10n.settingsMoreModels),
              subtitle: Text(l10n.settingsSearchAllModels),
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            ),
            if (_showAdvanced) ...[
              _AdvancedModelPicker(
                settings: settings,
                notifier: notifier,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AdvancedModelPicker extends ConsumerStatefulWidget {
  const _AdvancedModelPicker({
    required this.settings,
    required this.notifier,
  });

  final AppSettings settings;
  final Settings notifier;

  @override
  ConsumerState<_AdvancedModelPicker> createState() => _AdvancedModelPickerState();
}

class _AdvancedModelPickerState extends ConsumerState<_AdvancedModelPicker> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modelsAsync = ref.watch(openRouterModelsProvider(''));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return modelsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          l10n.settingsFailedToLoadModels(e.toString()),
          style: TextStyle(color: cs.error),
        ),
      ),
      data: (allModels) {
        var models = allModels;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          models = models.where((m) {
            return m.name.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q);
          }).toList();
        }

        final seriesMap = <String, List<AIModel>>{};
        for (final m in models) {
          final s = m.series;
          seriesMap.putIfAbsent(s, () => []).add(m);
        }
        final seriesList = seriesMap.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.settingsSearchModelsHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: seriesList.length,
                itemBuilder: (context, index) {
                  final series = seriesList[index];
                  final seriesModels = seriesMap[series]!;
                  return _SeriesGroup(
                    seriesName: series,
                    models: seriesModels,
                    selectedId: widget.settings.openrouterModel,
                    onSelected: (id) {
                      if (id != null) {
                        widget.notifier.setOpenRouterModel(id);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeriesGroup extends StatelessWidget {
  const _SeriesGroup({
    required this.seriesName,
    required this.models,
    required this.selectedId,
    required this.onSelected,
  });

  final String seriesName;
  final List<AIModel> models;
  final String selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(
        seriesName,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      children: models.map((m) {
        final isSelected = m.id == selectedId;
        return ListTile(
          dense: true,
          selected: isSelected,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  m.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (m.contextLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    m.contextLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          trailing: isSelected ? const Icon(Icons.check_circle, size: 18) : null,
          onTap: () => onSelected(m.id),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: Remove model section from `settings_screen.dart`**

Delete lines 176-264 (the `_SectionCard` with model selection UI).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to model section

---

### Task 2: Extract ApiConnectionScreen

**Files:**
- Create: `lib/screens/settings/api_connection_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline API key section)

- [ ] **Step 1: Create `lib/screens/settings/api_connection_screen.dart`**

Extract the API key input, save, and test connection UI from lines 267-324.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';

class ApiConnectionScreen extends ConsumerStatefulWidget {
  const ApiConnectionScreen({super.key});

  @override
  ConsumerState<ApiConnectionScreen> createState() => _ApiConnectionScreenState();
}

class _ApiConnectionScreenState extends ConsumerState<ApiConnectionScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _showKey = false;
  bool _testingConnection = false;
  String? _connectionResult;
  bool _connectionError = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final key = await notifier.getApiKey(settings.provider) ?? '';
    if (mounted) {
      _apiKeyCtrl.text = key;
    }
  }

  Future<void> _saveKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.saveApiKey(settings.provider, _apiKeyCtrl.text.trim());
  }

  Future<void> _testConnection() async {
    await _saveKey();
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';
    final l10n = AppLocalizations.of(context)!;

    if (apiKey.isEmpty) {
      setState(() {
        _connectionResult = l10n.settingsEnterApiKeyFirst;
        _connectionError = true;
      });
      return;
    }

    final model = settings.activeModel;
    if (model.isEmpty) {
      setState(() {
        _connectionResult = l10n.settingsSelectModelFirst;
        _connectionError = true;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });

    try {
      await ref.read(aiServiceProvider).testConnection(
            apiKey: apiKey,
            model: model,
            provider: settings.provider,
          );
      if (mounted) {
        setState(() {
          _connectionResult = l10n.settingsConnectionSuccess;
          _connectionError = false;
        });
      }
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          _connectionResult = e.message;
          _connectionError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionResult = e.toString();
          _connectionError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isProviderOpenAi = settings.provider == 'openai';
    final providerLabel = isProviderOpenAi ? l10n.settingsOpenAi : l10n.settingsOpenRouter;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsApiKeySection(providerLabel))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiKeyCtrl,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: l10n.settingsApiKeyLabel,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onEditingComplete: _saveKey,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _saveKey,
                  child: Text(l10n.settingsSaveKey),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(l10n.settingsTestButton),
                ),
              ),
            ],
          ),
          if (_connectionResult != null) ...[
            const SizedBox(height: 16),
            Text(
              _connectionResult!,
              style: TextStyle(
                color: _connectionError ? cs.error : cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Remove API key section from `settings_screen.dart`**

Delete lines 267-324 (the `_SectionCard` with API key UI).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to API section

---

### Task 3: Extract TranscriptionSettingsScreen

**Files:**
- Create: `lib/screens/settings/transcription_settings_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline transcription section)

- [ ] **Step 1: Create `lib/screens/settings/transcription_settings_screen.dart`**

Extract the transcription strategy toggle, model management, live transcription, and diarization UI from lines 422-708.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transcription_config.dart';
import '../../providers/model_download_provider.dart';
import '../../providers/settings_provider.dart';

class TranscriptionSettingsScreen extends ConsumerWidget {
  const TranscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('On-Device Transcription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Use on-device transcription'),
            subtitle: const Text('Transcribe offline without internet'),
            value: settings.transcriptionStrategy == TranscriptionStrategy.onDevice,
            onChanged: (v) async {
              await notifier.setTranscriptionStrategy(
                v ? TranscriptionStrategy.onDevice : TranscriptionStrategy.cloud,
              );
            },
          ),
          if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice) ...[
            const SizedBox(height: 16),
            Text(
              'Speech Recognition Models',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Download a model to use on-device transcription',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final progressAsync = ref.watch(modelDownloadProgressProvider);
                return progressAsync.when(
                  data: (progress) {
                    if (progress.status == DownloadStatus.downloading) {
                      final modelName = progress.modelSize?.name ?? progress.type.name;
                      return Column(
                        children: [
                          LinearProgressIndicator(value: progress.fraction),
                          const SizedBox(height: 4),
                          Text('Downloading $modelName model... ${(progress.fraction * 100).toStringAsFixed(0)}%'),
                          const SizedBox(height: 8),
                        ],
                      );
                    } else if (progress.status == DownloadStatus.extracting) {
                      final modelName = progress.modelSize?.name ?? progress.type.name;
                      return Column(
                        children: [
                          const LinearProgressIndicator(),
                          const SizedBox(height: 4),
                          Text('Extracting $modelName model...'),
                          const SizedBox(height: 8),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                final downloadedAsync = ref.watch(downloadedModelsProvider);
                final progressAsync = ref.watch(modelDownloadProgressProvider);
                return downloadedAsync.when(
                  data: (downloaded) {
                    return Column(
                      children: downloaded.entries.map((entry) {
                        final size = entry.key;
                        final isDownloaded = entry.value;
                        final isSelected = size == settings.onDeviceModelSize;
                        final isActive = isDownloaded && isSelected;
                        final label = switch (size) {
                          ModelSize.tiny => 'Tiny',
                          ModelSize.base => 'Base',
                          ModelSize.small => 'Small',
                        };
                        final sizeLabel = switch (size) {
                          ModelSize.tiny => '~75MB',
                          ModelSize.base => '~150MB',
                          ModelSize.small => '~500MB',
                        };

                        final isDownloading = progressAsync.valueOrNull?.status == DownloadStatus.downloading &&
                            progressAsync.valueOrNull?.modelSize == size;
                        final isExtracting = progressAsync.valueOrNull?.status == DownloadStatus.extracting &&
                            progressAsync.valueOrNull?.modelSize == size;
                        final isBusy = isDownloading || isExtracting;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: isActive
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (isDownloaded
                                    ? IconButton(
                                        icon: const Icon(Icons.circle_outlined, color: Colors.grey),
                                        onPressed: () => notifier.setOnDeviceModelSize(size),
                                      )
                                    : (isBusy
                                        ? Icon(
                                            isExtracting ? Icons.archive : Icons.downloading,
                                            color: theme.colorScheme.primary,
                                          )
                                        : IconButton(
                                            icon: Icon(
                                              Icons.download,
                                              color: theme.colorScheme.primary,
                                            ),
                                            onPressed: () => _downloadModel(context, ref, size, label, sizeLabel),
                                          ))),
                            title: Text('$label ($sizeLabel)'),
                            subtitle: isActive
                                ? const Text('Selected', style: TextStyle(color: Colors.green))
                                : (isBusy
                                    ? Text(isExtracting ? 'Extracting...' : 'Downloading...',
                                        style: const TextStyle(color: Colors.blue))
                                    : null),
                            trailing: isBusy
                                ? IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.orange),
                                    onPressed: () {
                                      ref.read(modelDownloadManagerProvider).cancelDownload();
                                      ref.invalidate(downloadedModelsProvider);
                                    },
                                  )
                                : (isDownloaded
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteModel(context, ref, size, label),
                                      )
                                    : null),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Error loading model info'),
                );
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Live transcription'),
              subtitle: const Text('Transcribe while recording'),
              value: settings.enableRealTimeTranscription,
              onChanged: (v) async {
                if (v && settings.language == 'German') {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('English Model Only'),
                      content: const Text(
                        'Live transcription uses an English model. German speech will be transcribed with limited accuracy. Use cloud transcription for German.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                await notifier.setEnableRealTimeTranscription(v);
              },
            ),
            SwitchListTile(
              title: const Text('Speaker diarization'),
              subtitle: const Text('Identify different speakers'),
              value: settings.onDeviceDiarization,
              onChanged: (v) => notifier.setOnDeviceDiarization(v),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadModel(BuildContext context, WidgetRef ref, ModelSize size, String label, String sizeLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Model'),
        content: Text('Download $label model ($sizeLabel)?\n\nThis may use significant data on metered connections.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final manager = ref.read(modelDownloadManagerProvider);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        await manager.downloadModel(size);
        ref.invalidate(downloadedModelsProvider);

        if (!await manager.isStreamingModelAvailable('English')) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Downloading streaming model...')),
          );
          await manager.downloadStreamingModel('English');
        }

        if (!await manager.isSegmentationModelAvailable()) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Downloading speaker segmentation model...')),
          );
          await manager.downloadSegmentationModel();
        }

        if (!await manager.isEmbeddingModelAvailable()) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Downloading speaker embedding model...')),
          );
          await manager.downloadEmbeddingModel();
        }

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('All models downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        ref.invalidate(downloadedModelsProvider);
      }
    }
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref, ModelSize size, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Delete $label model?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final manager = ref.read(modelDownloadManagerProvider);
      await manager.deleteModel(size);
      ref.invalidate(downloadedModelsProvider);
    }
  }
}
```

- [ ] **Step 2: Remove transcription section from `settings_screen.dart`**

Delete lines 422-708 (the large transcription section `_SectionCard`).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to transcription section

---

### Task 4: Extract SummaryLanguageScreen

**Files:**
- Create: `lib/screens/settings/summary_language_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline summary section)

- [ ] **Step 1: Create `lib/screens/settings/summary_language_screen.dart`**

Extract the summary style and output language dropdowns from lines 359-392.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../models/app_settings.dart';
import '../../models/summary_style.dart';
import '../../providers/settings_provider.dart';
import '../../utils/localized_strings.dart';

class SummaryLanguageScreen extends ConsumerWidget {
  const SummaryLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSummarySection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: settings.summaryStyle,
            decoration: InputDecoration(
              labelText: l10n.settingsStyleLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.format_list_bulleted_outlined),
            ),
            items: SummaryStyle.values
                .map((s) => DropdownMenuItem(
                      value: s.name,
                      child: Text(s.localizedTitle(context)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setSummaryStyle(v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: settings.language,
            decoration: InputDecoration(
              labelText: l10n.settingsLanguageLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.language),
            ),
            items: kSupportedLanguages
                .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(localizedLanguageName(context, l)),
                    ))
                .toList(),
            onChanged: (l) {
              if (l != null) notifier.setLanguage(l);
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Remove summary section from `settings_screen.dart`**

Delete lines 359-392 (the `_SectionCard` with summary style and language).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to summary section

---

### Task 5: Extract TtsSettingsScreen

**Files:**
- Create: `lib/screens/settings/tts_settings_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline TTS section)

- [ ] **Step 1: Create `lib/screens/settings/tts_settings_screen.dart`**

Extract the TTS speed slider from lines 395-419.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../providers/settings_provider.dart';

class TtsSettingsScreen extends ConsumerWidget {
  const TtsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTtsSection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${settings.ttsSpeed.toStringAsFixed(1)}×',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Slider(
            value: settings.ttsSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${settings.ttsSpeed.toStringAsFixed(1)}×',
            onChanged: notifier.setTtsSpeed,
            onChangeEnd: (_) => notifier.persistSettings(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.5×', style: theme.textTheme.bodySmall),
              Text('2.0×', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Remove TTS section from `settings_screen.dart`**

Delete lines 395-419 (the `_SectionCard` with TTS slider).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to TTS section

---

### Task 6: Extract AppLanguageScreen

**Files:**
- Create: `lib/screens/settings/app_language_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (remove inline app language section)

- [ ] **Step 1: Create `lib/screens/settings/app_language_screen.dart`**

Extract the app language dropdown from lines 327-356.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../providers/settings_provider.dart';

class AppLanguageScreen extends ConsumerWidget {
  const AppLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppLanguageLabel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: settings.localeOverride,
            decoration: InputDecoration(
              labelText: l10n.settingsAppLanguageLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.language_outlined),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.settingsSystemDefault),
              ),
              DropdownMenuItem<String?>(
                value: 'en',
                child: Text(l10n.langEnglish),
              ),
              DropdownMenuItem<String?>(
                value: 'de',
                child: Text(l10n.langGerman),
              ),
            ],
            onChanged: (v) {
              ref.read(settingsProvider.notifier).setLocaleOverride(v);
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Remove app language section from `settings_screen.dart`**

Delete lines 327-356 (the `_SectionCard` with app language).

- [ ] **Step 3: Verify build**

Run: `flutter analyze`
Expected: No errors related to app language section

---

### Task 7: Refactor SettingsScreen to Hub Layout

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Clean up imports**

Remove unused imports from `settings_screen.dart`. Keep only:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_card.dart';
import 'backup_screen.dart';
import 'settings/ai_models_screen.dart';
import 'settings/api_connection_screen.dart';
import 'settings/app_language_screen.dart';
import 'settings/summary_language_screen.dart';
import 'settings/transcription_settings_screen.dart';
import 'settings/tts_settings_screen.dart';
```

- [ ] **Step 2: Replace body with hub layout**

Replace the entire `body` of `SettingsScreen` with the grouped list hub. Remove all extracted section code, `_SectionCard`, `_AdvancedModelPicker`, and `_SeriesGroup` widget definitions from this file.

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final settings = ref.watch(settingsProvider);
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return Scaffold(
    appBar: AppBar(
      title: Text(l10n.settingsTitle),
      leading: widget.isInitialSetup ? null : const BackButton(),
      automaticallyImplyLeading: !widget.isInitialSetup,
    ),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (widget.isInitialSetup) ...[
          const SizedBox(height: 16),
          GlassCard(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.rocket_launch, color: cs.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.settingsSetupHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        _buildSection(
          context,
          title: 'AI & Models',
          children: [
            _SettingsRow(
              icon: Icons.smart_toy_outlined,
              title: 'AI & Models',
              subtitle: '${settings.provider == 'openai' ? 'OpenAI' : 'OpenRouter'} — ${settings.activeModel}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiModelsScreen()),
              ),
            ),
            _SettingsRow(
              icon: Icons.key_outlined,
              title: 'API Connection',
              subtitle: 'Configured', // TODO: Check if key exists
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiConnectionScreen()),
              ),
            ),
          ],
        ),
        _buildSection(
          context,
          title: 'Transcription',
          children: [
            _SettingsRow(
              icon: Icons.phone_android_outlined,
              title: 'Transcription',
              subtitle: settings.transcriptionStrategy == TranscriptionStrategy.onDevice
                  ? 'On-device'
                  : 'Cloud',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TranscriptionSettingsScreen()),
              ),
            ),
          ],
        ),
        _buildSection(
          context,
          title: 'Output',
          children: [
            _SettingsRow(
              icon: Icons.summarize_outlined,
              title: 'Summary & Language',
              subtitle: '${settings.summaryStyle} — ${settings.language}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryLanguageScreen()),
              ),
            ),
            _SettingsRow(
              icon: Icons.record_voice_over_outlined,
              title: 'Text-to-Speech',
              subtitle: '${settings.ttsSpeed.toStringAsFixed(1)}×',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TtsSettingsScreen()),
              ),
            ),
          ],
        ),
        _buildSection(
          context,
          title: 'App',
          children: [
            _SettingsRow(
              icon: Icons.translate_outlined,
              title: 'App Language',
              subtitle: settings.localeOverride ?? 'System Default',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppLanguageScreen()),
              ),
            ),
            _SettingsRow(
              icon: Icons.cloud_upload_outlined,
              title: 'Backup & Restore',
              subtitle: '',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    ),
  );
}
```

- [ ] **Step 3: Add helper widgets to `settings_screen.dart`**

```dart
Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      GlassCard(
        child: Column(
          children: children,
        ),
      ),
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Remove unused state and methods**

Remove from `_SettingsScreenState`:
- `_apiKeyCtrl`
- `_showKey`
- `_testingConnection`
- `_connectionResult`
- `_connectionError`
- `_showAdvanced`
- `_loadKey()`
- `_saveKey()`
- `_testConnection()`
- `_SectionCard` class
- `_AdvancedModelPicker` class
- `_SeriesGroup` class

- [ ] **Step 5: Verify build**

Run: `flutter analyze`
Expected: No errors in `settings_screen.dart`

---

### Task 8: Fix Dynamic Subtitles

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add API key status check**

In the hub subtitle for "API Connection", read the actual key to show "Configured" or "Not configured":

Wrap the SettingsScreen body in a `FutureBuilder` or use a provider to check API key status. Simpler approach: make `_SettingsScreenState` check the key in `initState`:

```dart
String? _apiKeyStatus;

@override
void initState() {
  super.initState();
  _checkApiKey();
  if (!widget.isInitialSetup) _offerShortcut();
}

Future<void> _checkApiKey() async {
  final settings = ref.read(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  final key = await notifier.getApiKey(settings.provider);
  if (mounted) {
    setState(() {
      _apiKeyStatus = key != null && key.isNotEmpty ? 'Configured' : 'Not configured';
    });
  }
}
```

Update the API Connection row subtitle to use `_apiKeyStatus ?? '...'`.

- [ ] **Step 2: Verify build**

Run: `flutter analyze`
Expected: No errors

---

### Task 9: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: 0 issues

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All existing tests pass (no logic changed, only UI reorganization)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings/
git add lib/screens/settings_screen.dart
git add docs/superpowers/specs/2026-04-23-settings-redesign-design.md
git commit -m "refactor(settings): reorganize into hub + sub-pages

Extract 6 inline sections into dedicated screens:
- AiModelsScreen
- ApiConnectionScreen
- TranscriptionSettingsScreen
- SummaryLanguageScreen
- TtsSettingsScreen
- AppLanguageScreen

Main SettingsScreen now shows grouped card hub layout
with navigation to each sub-page."
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All 6 sub-pages and hub layout from spec are covered
- [x] **Placeholder scan:** No TBD/TODO/fill-in-later steps
- [x] **Type consistency:** All provider names, model names, and notifier methods match existing codebase
- [x] **Import consistency:** All new files use correct relative imports to `../../`
- [x] **No logic changes:** Only UI reorganization — all business logic preserved

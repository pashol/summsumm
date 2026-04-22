import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../models/app_settings.dart';
import '../models/ai_model.dart';
import '../models/summary_style.dart';
import '../models/transcription_config.dart';
import '../providers/models_provider.dart';
import '../providers/model_download_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../utils/localized_strings.dart';
import '../widgets/glass_card.dart';
import 'backup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.isInitialSetup = false});

  final bool isInitialSetup;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _showKey = false;
  bool _testingConnection = false;
  String? _connectionResult;
  bool _connectionError = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _loadKey();

    if (!widget.isInitialSetup) _offerShortcut();
  }

  Future<void> _loadKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final key = await notifier.getApiKey(settings.provider) ?? '';
    if (mounted) {
      _apiKeyCtrl.text = key;
    }
  }

  Future<void> _offerShortcut() async {
    try {
      const channel = MethodChannel('app.summsumm/intent');
      await channel.invokeMethod('offerSettingsShortcut');
    } catch (_) {}
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

    if (apiKey.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsEnterApiKeyFirst;
        _connectionError = true;
      });
      return;
    }

    final model = settings.activeModel;

    if (model.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsSelectModelFirst;
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
          _connectionResult = AppLocalizations.of(context)!.settingsConnectionSuccess;
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isProviderOpenAi = settings.provider == 'openai';
    final providerLabel = isProviderOpenAi ? l10n.settingsOpenAi : l10n.settingsOpenRouter;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: widget.isInitialSetup ? null : const BackButton(),
        automaticallyImplyLeading: !widget.isInitialSetup,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isInitialSetup) ...[
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
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: l10n.settingsModelSection,
            icon: Icons.smart_toy_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.provider,
                decoration: InputDecoration(
                  labelText: l10n.settingsProviderLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.dns_outlined),
                ),
                items: [
                   DropdownMenuItem(
                       value: 'openrouter', child: Text(l10n.settingsOpenRouter),),
                  DropdownMenuItem(value: 'openai', child: Text(l10n.settingsOpenAi)),
                ],
                onChanged: (v) async {
                  if (v != null && v != settings.provider) {
                    await notifier.setProvider(v);
                    await _loadKey();
                  }
                },
              ),
              const SizedBox(height: 12),
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
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),)
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
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),)
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setOpenRouterModel(v);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  ),
                  title: Text(l10n.settingsMoreModels),
                  subtitle: Text(l10n.settingsSearchAllModels),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                ),
                if (_showAdvanced) ...[
                  if (_apiKeyCtrl.text.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.settingsEnterKeyFirst,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    _AdvancedModelPicker(
                      settings: settings,
                      notifier: notifier,
                      apiKey: _apiKeyCtrl.text.trim(),
                    ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsApiKeySection(providerLabel),
            icon: Icons.key_outlined,
            children: [
              TextField(
                controller: _apiKeyCtrl,
                obscureText: !_showKey,
                decoration: InputDecoration(
                  labelText: l10n.settingsApiKeyLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility,),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
                onEditingComplete: _saveKey,
              ),
              const SizedBox(height: 8),
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
                const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsAppLanguageLabel,
            icon: Icons.translate_outlined,
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
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsSummarySection,
            icon: Icons.summarize_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.summaryStyle,
                decoration: InputDecoration(
                  labelText: l10n.settingsStyleLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.format_list_bulleted_outlined),
                ),
                items: SummaryStyle.values
                    .map((s) => DropdownMenuItem(value: s.name, child: Text(s.localizedTitle(context))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) notifier.setSummaryStyle(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.language,
                decoration: InputDecoration(
                  labelText: l10n.settingsLanguageLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.language),
                ),
                items: kSupportedLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(localizedLanguageName(context, l))))
                    .toList(),
                onChanged: (l) {
                  if (l != null) notifier.setLanguage(l);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsTtsSection,
            icon: Icons.record_voice_over_outlined,
            children: [
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
                  Text(
                    '${settings.ttsSpeed.toStringAsFixed(1)}×',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text('2.0×', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'On-Device Transcription',
            icon: Icons.phone_android_outlined,
            children: [
              // Enable on-device transcription
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
              
              // Model Management Section (only when on-device enabled)
              if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice) ...[
                const SizedBox(height: 16),
                Text(
                  'Speech Recognition Models',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download a model to use on-device transcription',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Download progress
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
                            
                            // Check if this model is currently downloading
                            final isDownloading = progressAsync.valueOrNull?.status == DownloadStatus.downloading &&
                                progressAsync.valueOrNull?.modelSize == size;
                            final isExtracting = progressAsync.valueOrNull?.status == DownloadStatus.extracting &&
                                progressAsync.valueOrNull?.modelSize == size;
                            final isBusy = isDownloading || isExtracting;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: isActive
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : (isDownloaded
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.circle_outlined,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => notifier.setOnDeviceModelSize(size),
                                        )
                                      : (isBusy
                                          ? Icon(
                                              isExtracting ? Icons.archive : Icons.downloading,
                                              color: Theme.of(context).colorScheme.primary,
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                Icons.download,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              onPressed: () async {
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
                                              },
                                            ))),
                                title: Text('$label ($sizeLabel)'),
                                subtitle: isActive
                                  ? const Text('Selected', style: TextStyle(color: Colors.green))
                                  : (isBusy
                                      ? Text(isExtracting ? 'Extracting...' : 'Downloading...', style: const TextStyle(color: Colors.blue))
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
                                          onPressed: () async {
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
                                          },
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
                
                // Live transcription toggle
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
                
                // Diarization toggle
                SwitchListTile(
                  title: const Text('Speaker diarization'),
                  subtitle: const Text('Identify different speakers'),
                  value: settings.onDeviceDiarization,
                  onChanged: (v) => notifier.setOnDeviceDiarization(v),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.backupSettingsSection,
            icon: Icons.cloud_upload_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: Text(l10n.backupTitle),
                subtitle: Text(l10n.backupSettingsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GlassCard(
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
                  child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AdvancedModelPicker extends ConsumerStatefulWidget {
  const _AdvancedModelPicker({
    required this.settings,
    required this.notifier,
    required this.apiKey,
  });

  final AppSettings settings;
  final Settings notifier;
  final String apiKey;

  @override
  ConsumerState<_AdvancedModelPicker> createState() =>
      _AdvancedModelPickerState();
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
    final modelsAsync = ref.watch(openRouterModelsProvider(widget.apiKey));
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
          AppLocalizations.of(context)!.settingsFailedToLoadModels(e.toString()),
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.settingsSearchModelsHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ],
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
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
          trailing:
              isSelected ? const Icon(Icons.check_circle, size: 18) : null,
          onTap: () => onSelected(m.id),
        );
      }).toList(),
    );
  }
}

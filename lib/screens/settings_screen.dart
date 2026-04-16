import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/ai_model.dart';
import '../providers/models_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/neumorphic_button.dart';

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
        _connectionResult = 'Enter an API key first';
        _connectionError = true;
      });
      return;
    }

    final model = settings.activeModel;

    if (model.isEmpty) {
      setState(() {
        _connectionResult = 'Select a model first';
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
          _connectionResult = 'Connection successful!';
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
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isProviderOpenAi = settings.provider == 'openai';
    final providerLabel = isProviderOpenAi ? 'OpenAI' : 'OpenRouter';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                        'Set your API key to get started.',
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
            title: 'Model',
            icon: Icons.smart_toy_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.provider,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'openrouter', child: Text('OpenRouter')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
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
                      ? null
                      : settings.openaiModel,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.psychology_outlined),
                  ),
                  items: kOpenAiModels
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ))
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
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.psychology_outlined),
                  ),
                  items: kCuratedModels
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ))
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
                  title: const Text('More models'),
                  subtitle: const Text('Search all OpenRouter models'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                ),
                if (_showAdvanced) ...[
                  if (_apiKeyCtrl.text.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Enter your API key first to load models.',
                        style: TextStyle(fontStyle: FontStyle.italic),
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
            title: '$providerLabel API Key',
            icon: Icons.key_outlined,
            children: [
              TextField(
                controller: _apiKeyCtrl,
                obscureText: !_showKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility),
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
                      child: const Text('Save Key'),
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
                      label: const Text('Test Connection'),
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
            title: 'Summary',
            icon: Icons.summarize_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.language,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                items: kSupportedLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (l) {
                  if (l != null) notifier.setLanguage(l);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Text-to-Speech',
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
          'Failed to load models: $e',
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
                    decoration: const InputDecoration(
                      hintText: 'Search models...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
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

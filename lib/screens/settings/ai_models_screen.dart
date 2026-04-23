import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../models/app_settings.dart';
import '../../models/ai_model.dart';
import '../../providers/models_provider.dart';
import '../../providers/settings_provider.dart';

class AiModelsScreen extends ConsumerStatefulWidget {
  const AiModelsScreen({super.key});

  @override
  ConsumerState<AiModelsScreen> createState() => _AiModelsScreenState();
}

class _AiModelsScreenState extends ConsumerState<AiModelsScreen> {
  bool _showAdvanced = false;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final key = await notifier.getApiKey(settings.provider) ?? '';
    if (mounted) {
      setState(() => _apiKey = key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isProviderOpenAi = settings.provider == 'openai';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsModelSection),
      ),
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
              DropdownMenuItem(
                value: 'openrouter',
                child: Text(l10n.settingsOpenRouter),
              ),
              DropdownMenuItem(
                value: 'openai',
                child: Text(l10n.settingsOpenAi),
              ),
            ],
            onChanged: (v) async {
              if (v != null && v != settings.provider) {
                await notifier.setProvider(v);
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
              if (_apiKey.trim().isEmpty)
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
                  apiKey: _apiKey.trim(),
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

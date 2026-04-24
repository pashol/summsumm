import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../models/custom_prompt.dart';
import '../../models/summary_style.dart';
import '../../providers/settings_provider.dart';
import '../../utils/prompt_resolver.dart';
import '../../widgets/glass_card.dart';

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen({super.key});

  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  SummaryStyle _selectedStyle = SummaryStyle.structured;
  final _promptController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPromptForStyle();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  void _loadPromptForStyle() {
    final settings = ref.read(settingsProvider);
    final text = PromptResolver.resolve(style: _selectedStyle, settings: settings);
    _promptController.text = text;
  }

  void _onPromptChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.setPromptOverride(_selectedStyle.name, text);
    });
  }

  void _resetPrompt() {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.resetPromptOverride(_selectedStyle.name);
    final settings = ref.read(settingsProvider);
    final text = PromptResolver.resolve(style: _selectedStyle, settings: settings);
    _promptController.text = text;
  }

  Future<void> _showAddCustomPromptSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _CustomPromptSheet(
          onSave: (name, text) {
            ref.read(settingsProvider.notifier).addCustomPrompt(name, text);
          },
        );
      },
    );
  }

  Future<void> _showEditCustomPromptSheet(CustomPrompt prompt) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _CustomPromptSheet(
          initialName: prompt.name,
          initialText: prompt.text,
          title: l10n.editPromptTitle,
          onSave: (name, text) {
            ref.read(settingsProvider.notifier).updateCustomPrompt(prompt.id, name: name, text: text);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(CustomPrompt prompt) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePromptTitle),
        content: Text(l10n.deletePromptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(settingsProvider.notifier).deleteCustomPrompt(prompt.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final hasOverride = settings.promptOverrides.containsKey(_selectedStyle.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.promptEditorTitle),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        children: [
          const SizedBox(height: 8),
          _SectionTitle(title: l10n.defaultPromptSection),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<SummaryStyle>(
                    initialValue: _selectedStyle,
                    decoration: InputDecoration(
                      labelText: l10n.summaryStyleLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: SummaryStyle.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (style) {
                      if (style != null) {
                        _debounceTimer?.cancel();
                        setState(() {
                          _selectedStyle = style;
                        });
                        _loadPromptForStyle();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promptController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.promptTextLabel,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: _onPromptChanged,
                  ),
                  if (hasOverride) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _resetPrompt,
                        icon: const Icon(Icons.restore),
                        label: Text(l10n.resetToDefault),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _SectionTitle(title: l10n.customPromptsSection),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddCustomPromptSheet,
              ),
            ],
          ),
          if (settings.customPrompts.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    l10n.noCustomPrompts,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            )
          else
            ...settings.customPrompts.map(
              (prompt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                prompt.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showEditCustomPromptSheet(prompt),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _confirmDelete(prompt),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prompt.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomPromptSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CustomPromptSheet extends StatefulWidget {
  final String? initialName;
  final String? initialText;
  final String? title;
  final void Function(String name, String text) onSave;

  const _CustomPromptSheet({
    this.initialName,
    this.initialText,
    this.title,
    required this.onSave,
  });

  @override
  State<_CustomPromptSheet> createState() => _CustomPromptSheetState();
}

class _CustomPromptSheetState extends State<_CustomPromptSheet> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _textController = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final text = _textController.text.trim();
    if (name.isNotEmpty && text.isNotEmpty) {
      widget.onSave(name, text);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title ?? l10n.newPromptTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.promptNameLabel,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.promptTextLabel,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

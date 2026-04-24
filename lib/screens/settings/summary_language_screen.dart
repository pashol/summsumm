import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../../models/app_settings.dart';
import '../../models/summary_style.dart';
import '../../providers/settings_provider.dart';
import '../../utils/localized_strings.dart';

class SummaryLanguageScreen extends ConsumerWidget {
  const SummaryLanguageScreen({super.key});

  String _getSelectedValue(AppSettings settings) {
    if (settings.selectedCustomPromptId != null) {
      return 'custom:${settings.selectedCustomPromptId}';
    }
    return settings.summaryStyle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSummarySection),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _getSelectedValue(settings),
            decoration: InputDecoration(
              labelText: l10n.settingsStyleLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.format_list_bulleted_outlined),
            ),
            items: [
              ...SummaryStyle.values.map((s) => DropdownMenuItem(value: s.name, child: Text(s.localizedTitle(context)))),
              if (settings.customPrompts.isNotEmpty) ...[
                const DropdownMenuItem(enabled: false, child: Divider()),
                ...settings.customPrompts.map((p) => DropdownMenuItem(value: 'custom:${p.id}', child: Text(p.name))),
              ],
            ],
            onChanged: (v) {
              if (v != null) {
                if (v.startsWith('custom:')) {
                  final id = v.substring(7);
                  notifier.setSelectedCustomPrompt(id);
                } else {
                  notifier.setSummaryStyle(v);
                  notifier.setSelectedCustomPrompt(null);
                }
              }
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
    );
  }
}

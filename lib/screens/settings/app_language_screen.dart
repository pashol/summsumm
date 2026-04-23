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
      appBar: AppBar(
        title: Text(l10n.settingsAppLanguageLabel),
      ),
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

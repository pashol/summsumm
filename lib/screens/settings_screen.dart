import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../providers/settings_provider.dart';
import '../utils/localized_strings.dart';
import '../widgets/glass_card.dart';
import 'backup_screen.dart';
import 'settings/app_language_screen.dart';
import 'settings/summary_language_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.isInitialSetup = false});

  final bool isInitialSetup;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.isInitialSetup) _offerShortcut();
  }

  Future<void> _offerShortcut() async {
    try {
      const channel = MethodChannel('app.summsumm/intent');
      await channel.invokeMethod('offerSettingsShortcut');
    } catch (_) {}
  }

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
            title: l10n.settingsAppLanguageLabel,
            icon: Icons.translate_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.settingsAppLanguageLabel),
                subtitle: Text(
                  settings.localeOverride == null
                      ? l10n.settingsSystemDefault
                      : settings.localeOverride == 'en'
                          ? l10n.langEnglish
                          : l10n.langGerman,
                ),
                trailing: const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AppLanguageScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsSummarySection,
            icon: Icons.summarize_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.summarize),
                title: Text(l10n.settingsSummarySection),
                subtitle: Text('${settings.summaryStyle}, ${localizedLanguageName(context, settings.language)}'),
                trailing: const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SummaryLanguageScreen()),
                  );
                },
              ),
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



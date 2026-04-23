import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../models/summary_style.dart';
import '../models/transcription_config.dart';
import '../providers/settings_provider.dart';
import '../utils/localized_strings.dart';
import '../widgets/glass_card.dart';
import 'backup_screen.dart';
import 'settings/ai_models_screen.dart';
import 'settings/api_connection_screen.dart';
import 'settings/app_language_screen.dart';
import 'settings/summary_language_screen.dart';
import 'settings/transcription_settings_screen.dart';
import 'settings/tts_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.isInitialSetup = false});

  final bool isInitialSetup;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _apiKeyStatus;

  @override
  void initState() {
    super.initState();
    if (!widget.isInitialSetup) _offerShortcut();
    _loadApiKeyStatus();
  }

  Future<void> _offerShortcut() async {
    try {
      const channel = MethodChannel('app.summsumm/intent');
      await channel.invokeMethod('offerSettingsShortcut');
    } catch (_) {}
  }

  Future<void> _loadApiKeyStatus() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final key = await notifier.getApiKey(settings.provider);
    final status = (key != null && key.isNotEmpty)
        ? AppLocalizations.of(context)!.settingsConfigured
        : AppLocalizations.of(context)!.settingsNotConfigured;
    if (mounted) {
      setState(() => _apiKeyStatus = status);
    }
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

          // Section: AI & Models
          _SettingsSection(
            title: l10n.settingsAiModelsSection,
            children: [
              _SettingsRow(
                icon: Icons.psychology,
                title: l10n.settingsAiModelsRow,
                subtitle: settings.activeModel.isEmpty
                    ? (settings.provider == 'openrouter' ? l10n.settingsOpenRouter : l10n.settingsOpenAi)
                    : '${settings.provider == 'openrouter' ? l10n.settingsOpenRouter : l10n.settingsOpenAi} — ${settings.activeModel}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AiModelsScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SettingsRow(
                icon: Icons.key,
                title: l10n.settingsApiConnectionRow,
                subtitle: _apiKeyStatus ?? '',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ApiConnectionScreen()),
                  );
                },
              ),
            ],
          ),

          // Section: Transcription
          _SettingsSection(
            title: l10n.settingsTranscriptionSection,
            children: [
              _SettingsRow(
                icon: Icons.phone,
                title: l10n.settingsTranscriptionRow,
                subtitle: settings.transcriptionStrategy == TranscriptionStrategy.onDevice
                    ? l10n.settingsOnDevice
                    : l10n.settingsCloud,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const TranscriptionSettingsScreen()),
                  );
                },
              ),
            ],
          ),

          // Section: Output
          _SettingsSection(
            title: l10n.settingsOutputSection,
            children: [
              _SettingsRow(
                icon: Icons.summarize,
                title: l10n.settingsSummaryLanguageRow,
                subtitle: '${SummaryStyle.values.byName(settings.summaryStyle).localizedTitle(context)}, ${localizedLanguageName(context, settings.language)}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SummaryLanguageScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SettingsRow(
                icon: Icons.record_voice_over,
                title: l10n.settingsTtsRow,
                subtitle: '${settings.ttsSpeed}x',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const TtsSettingsScreen()),
                  );
                },
              ),
            ],
          ),

          // Section: App
          _SettingsSection(
            title: l10n.settingsAppSection,
            children: [
              _SettingsRow(
                icon: Icons.translate,
                title: l10n.settingsAppLanguageRow,
                subtitle: settings.localeOverride == null
                    ? l10n.settingsSystemDefault
                    : settings.localeOverride == 'en'
                        ? l10n.langEnglish
                        : l10n.langGerman,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AppLanguageScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SettingsRow(
                icon: Icons.backup,
                title: l10n.settingsBackupRestoreRow,
                subtitle: '',
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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

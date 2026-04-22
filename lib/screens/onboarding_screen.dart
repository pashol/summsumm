import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/providers/models_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/screens/meeting_library_screen.dart';
import 'package:summsumm/screens/settings_screen.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/widgets/glass_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingServiceProvider = Provider((ref) => OnboardingService());

class OnboardingService {
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_completed_onboarding') ?? false;
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _apiKeyCtrl = TextEditingController();
  int _currentPage = 0;
  bool _showKey = false;
  bool _testingConnection = false;
  String? _connectionResult;
  bool _connectionError = false;
  bool _configuredApiKey = false;
  String _selectedProvider = 'openrouter';
  String _selectedModel = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedProvider = settings.provider;
    _selectedModel = settings.provider == 'openai'
        ? (settings.openaiModel.isEmpty ? kOpenAiModels.first.id : settings.openaiModel)
        : (settings.openrouterModel.isEmpty ? kCuratedModels.first.id : settings.openrouterModel);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _testConnection() async {
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsEnterApiKeyFirst;
        _connectionError = true;
      });
      return;
    }

    final model = _selectedModel;
    if (model.isEmpty) {
      setState(() {
        _connectionResult = AppLocalizations.of(context)!.settingsSelectModelFirst;
        _connectionError = true;
      });
      return;
    }

    await notifier.saveApiKey(_selectedProvider, apiKey);

    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    try {
      await ref.read(aiServiceProvider).testConnection(
            apiKey: apiKey,
            model: model,
            provider: _selectedProvider,
          );
      if (mounted) {
        setState(() {
          _connectionResult = AppLocalizations.of(context)!.settingsConnectionSuccess;
          _connectionError = false;
          _configuredApiKey = true;
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

  Future<void> _complete() async {
    await ref.read(onboardingServiceProvider).completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MeetingLibraryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage < 3)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _skipToPage(3),
                  child: Text(l10n.onboardingSkipSetup),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _WelcomePage(
                    l10n: l10n,
                    theme: theme,
                    cs: cs,
                    onNext: _nextPage,
                  ),
                  _FeaturesPage(
                    l10n: l10n,
                    theme: theme,
                    cs: cs,
                    onNext: _nextPage,
                  ),
                  _ApiKeyPage(
                    l10n: l10n,
                    theme: theme,
                    cs: cs,
                    selectedProvider: _selectedProvider,
                    selectedModel: _selectedModel,
                    showKey: _showKey,
                    apiKeyCtrl: _apiKeyCtrl,
                    testingConnection: _testingConnection,
                    connectionResult: _connectionResult,
                    connectionError: _connectionError,
                    onShowKeyToggle: () => setState(() => _showKey = !_showKey),
                    onProviderChanged: (provider) async {
                      await notifier.setProvider(provider);
                      if (!mounted) return;
                      setState(() {
                        _selectedProvider = provider;
                        _selectedModel = provider == 'openai'
                            ? kOpenAiModels.first.id
                            : kCuratedModels.first.id;
                      });
                    },
                    onModelChanged: (model) async {
                      final modelNotifier = ref.read(settingsProvider.notifier);
                      if (_selectedProvider == 'openai') {
                        await modelNotifier.setOpenAiModel(model);
                      } else {
                        await modelNotifier.setOpenRouterModel(model);
                      }
                      if (!mounted) return;
                      setState(() {
                        _selectedModel = model;
                      });
                    },
                    onTestConnection: _testConnection,
                    onSkip: () {
                      _nextPage();
                    },
                    onNext: () {
                      if (_configuredApiKey || _apiKeyCtrl.text.trim().isNotEmpty) {
                        _nextPage();
                      }
                    },
                  ),
                  _QuickStartPage(
                    l10n: l10n,
                    theme: theme,
                    cs: cs,
                    configured: _configuredApiKey || _apiKeyCtrl.text.trim().isNotEmpty,
                    onComplete: _complete,
                    onGoToSettings: () async {
                      await ref.read(onboardingServiceProvider).completeOnboarding();
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const MeetingLibraryScreen(),
                          ),
                        ).then((_) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = _currentPage == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onNext;

  const _WelcomePage({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 120,
            color: cs.primary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingWelcomeTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.onboardingGetStarted),
          ),
        ],
      ),
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onNext;

  const _FeaturesPage({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingFeaturesTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _FeatureCard(
            icon: Icons.cloud,
            iconColor: cs.primary,
            title: l10n.onboardingOnlineFeatures,
            description: l10n.onboardingOnlineFeaturesDesc,
            theme: theme,
            cs: cs,
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.phone_android,
            iconColor: cs.secondary,
            title: l10n.onboardingOfflineFeatures,
            description: l10n.onboardingOfflineFeaturesDesc,
            theme: theme,
            cs: cs,
          ),
          const SizedBox(height: 24),
          GlassCard(
            color: cs.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.onTertiaryContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.onboardingTranscriptionNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onNext,
            child: Text(l10n.onboardingContinue),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final ThemeData theme;
  final ColorScheme cs;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.theme,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyPage extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final String selectedProvider;
  final String selectedModel;
  final bool showKey;
  final TextEditingController apiKeyCtrl;
  final bool testingConnection;
  final String? connectionResult;
  final bool connectionError;
  final VoidCallback onShowKeyToggle;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onTestConnection;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _ApiKeyPage({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.selectedProvider,
    required this.selectedModel,
    required this.showKey,
    required this.apiKeyCtrl,
    required this.testingConnection,
    required this.connectionResult,
    required this.connectionError,
    required this.onShowKeyToggle,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onTestConnection,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isProviderOpenAi = selectedProvider == 'openai';
    final models = isProviderOpenAi ? kOpenAiModels : kCuratedModels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingApiKeyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingApiKeySubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            initialValue: selectedProvider,
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
            onChanged: (v) {
              if (v != null && v != selectedProvider) {
                onProviderChanged(v);
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedModel.isEmpty ? models.first.id : selectedModel,
            decoration: InputDecoration(
              labelText: l10n.settingsModelSection,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.smart_toy_outlined),
            ),
            items: models
                .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    ),)
                .toList(),
            onChanged: (v) {
              if (v != null) {
                onModelChanged(v);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: apiKeyCtrl,
            obscureText: !showKey,
            decoration: InputDecoration(
              labelText: l10n.settingsApiKeyLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: onShowKeyToggle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (connectionResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: connectionError
                    ? cs.errorContainer
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                connectionResult!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: connectionError
                      ? cs.onErrorContainer
                      : cs.onPrimaryContainer,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: testingConnection ? null : onTestConnection,
                  icon: testingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(l10n.settingsTestButton),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onNext,
            child: Text(l10n.onboardingContinue),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSkip,
            child: Text(l10n.onboardingSkipForNow),
          ),
        ],
      ),
    );
  }
}

class _QuickStartPage extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final bool configured;
  final VoidCallback onComplete;
  final VoidCallback onGoToSettings;

  const _QuickStartPage({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.configured,
    required this.onComplete,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            configured ? Icons.check_circle : Icons.warning_amber,
            size: 100,
            color: configured ? cs.primary : cs.tertiary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingQuickStartTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            configured
                ? l10n.onboardingQuickStartOnline
                : l10n.onboardingQuickStartOffline,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.rocket_launch),
            label: Text(l10n.onboardingGetStarted),
          ),
          if (!configured) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onGoToSettings,
              child: Text(l10n.onboardingGoToSettings),
            ),
          ],
        ],
      ),
    );
  }
}
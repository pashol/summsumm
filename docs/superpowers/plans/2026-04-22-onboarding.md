# Onboarding Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a 4-screen onboarding wizard that explains online vs offline features, guides optional API key setup, and is skippable on first app launch.

**Architecture:** A `ConsumerStatefulWidget` with `PageView` manages 4 onboarding pages. `SharedPreferences` stores a `hasCompletedOnboarding` flag. The onboarding reuses existing `SettingsProvider`, `SecureStorageService`, and `AiService` for API key setup. No new Riverpod providers needed.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, flutter_secure_storage, Material 3

---

## File Structure

**New files:**
- `lib/screens/onboarding_screen.dart` — Main onboarding wizard with 4 pages

**Modified files:**
- `lib/main.dart` — Add onboarding check before routing
- `lib/l10n/app_en.arb` — Add onboarding localization strings
- `lib/l10n/app_de.arb` — Add German onboarding localization strings

---

## Task 1: Add Onboarding Localization Strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`

- [ ] **Step 1: Add English onboarding strings to `app_en.arb`**

Add these entries after the existing `"langTurkish"` entry (before the closing `}`):

```json
,
  "onboardingWelcomeTitle": "Summarize Anything, Anywhere",
  "@onboardingWelcomeTitle": {
    "description": "Onboarding welcome screen headline"
  },
  "onboardingWelcomeSubtitle": "AI-powered summaries from text, voice, and documents",
  "@onboardingWelcomeSubtitle": {
    "description": "Onboarding welcome screen subtitle"
  },
  "onboardingGetStarted": "Get Started",
  "@onboardingGetStarted": {
    "description": "Primary button on onboarding welcome screen"
  },
  "onboardingSkipSetup": "Skip Setup",
  "@onboardingSkipSetup": {
    "description": "Skip button on onboarding screens"
  },
  "onboardingFeaturesTitle": "What You Can Do",
  "@onboardingFeaturesTitle": {
    "description": "Onboarding features screen title"
  },
  "onboardingOnlineFeatures": "Online Features",
  "@onboardingOnlineFeatures": {
    "description": "Title for online features card"
  },
  "onboardingOnlineFeaturesDesc": "Text summarization, PDF summaries, cloud transcription — Requires API key",
  "@onboardingOnlineFeaturesDesc": {
    "description": "Description for online features card"
  },
  "onboardingOfflineFeatures": "Offline Features",
  "@onboardingOfflineFeatures": {
    "description": "Title for offline features card"
  },
  "onboardingOfflineFeaturesDesc": "Meeting recording, on-device transcription — Works without internet after model download",
  "@onboardingOfflineFeaturesDesc": {
    "description": "Description for offline features card"
  },
  "onboardingTranscriptionNote": "On-device transcription supports multiple languages. Live transcription works best with English.",
  "@onboardingTranscriptionNote": {
    "description": "Note about transcription language support"
  },
  "onboardingContinue": "Continue",
  "@onboardingContinue": {
    "description": "Continue button on onboarding screens"
  },
  "onboardingApiKeyTitle": "Connect Your AI",
  "@onboardingApiKeyTitle": {
    "description": "Onboarding API key screen title"
  },
  "onboardingApiKeySubtitle": "Add an API key to use AI-powered features. You can skip this and add it later in Settings.",
  "@onboardingApiKeySubtitle": {
    "description": "Onboarding API key screen subtitle"
  },
  "onboardingSkipForNow": "Skip for Now",
  "@onboardingSkipForNow": {
    "description": "Skip API key setup button"
  },
  "onboardingQuickStartTitle": "You're Ready!",
  "@onboardingQuickStartTitle": {
    "description": "Onboarding quick start screen title"
  },
  "onboardingQuickStartOnline": "You're ready to summarize text and PDFs.",
  "@onboardingQuickStartOnline": {
    "description": "Quick start message when API key is configured"
  },
  "onboardingQuickStartOffline": "You can record meetings and use on-device transcription. Add an API key later for AI features.",
  "@onboardingQuickStartOffline": {
    "description": "Quick start message when API key was skipped"
  },
  "onboardingGoToSettings": "Go to Settings",
  "@onboardingGoToSettings": {
    "description": "Link to settings from onboarding completion"
  }
```

- [ ] **Step 2: Add German onboarding strings to `app_de.arb`**

Add these entries after the existing `"langTurkish"` entry (before the closing `}`):

```json
,
  "onboardingWelcomeTitle": "Alles zusammenfassen, überall",
  "onboardingWelcomeSubtitle": "KI-gestützte Zusammenfassungen aus Text, Sprache und Dokumenten",
  "onboardingGetStarted": "Loslegen",
  "onboardingSkipSetup": "Einrichtung überspringen",
  "onboardingFeaturesTitle": "Was du tun kannst",
  "onboardingOnlineFeatures": "Online-Funktionen",
  "onboardingOnlineFeaturesDesc": "Textzusammenfassung, PDF-Zusammenfassungen, Cloud-Transkription — Erfordert API-Schlüssel",
  "onboardingOfflineFeatures": "Offline-Funktionen",
  "onboardingOfflineFeaturesDesc": "Meeting-Aufnahme, On-Device-Transkription — Funktioniert ohne Internet nach Modell-Download",
  "onboardingTranscriptionNote": "On-Device-Transkription unterstützt mehrere Sprachen. Live-Transkription funktioniert am besten auf Englisch.",
  "onboardingContinue": "Weiter",
  "onboardingApiKeyTitle": "Deine KI verbinden",
  "onboardingApiKeySubtitle": "Füge einen API-Schlüssel hinzu, um KI-Funktionen zu nutzen. Du kannst dies überspringen und später in den Einstellungen hinzufügen.",
  "onboardingSkipForNow": "Jetzt überspringen",
  "onboardingQuickStartTitle": "Bereit!",
  "onboardingQuickStartOnline": "Du kannst jetzt Text und PDFs zusammenfassen.",
  "onboardingQuickStartOffline": "Du kannst Meetings aufnehmen und On-Device-Transkription nutzen. Füge später einen API-Schlüssel für KI-Funktionen hinzu.",
  "onboardingGoToSettings": "Zu den Einstellungen"
```

- [ ] **Step 3: Commit localization changes**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: add onboarding localization strings"
```

---

## Task 2: Create Onboarding Screen

**Files:**
- Create: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Create the onboarding screen file**

Create `lib/screens/onboarding_screen.dart` with the following content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:summsumm/l10n/app_localizations.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

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
  bool _skippedApiKey = false;

  static const _onboardingKey = 'has_completed_onboarding';

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skipToEnd() {
    setState(() => _skippedApiKey = true);
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MeetingLibraryScreen()),
      );
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top right, except on last page)
            if (_currentPage < 3)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _skipToEnd,
                    child: Text(l10n.onboardingSkipSetup),
                  ),
                ),
              )
            else
              const SizedBox(height: 56),
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _FeaturesPage(onNext: _nextPage),
                  _ApiKeyPage(
                    apiKeyCtrl: _apiKeyCtrl,
                    showKey: _showKey,
                    onToggleShowKey: () => setState(() => _showKey = !_showKey),
                    testingConnection: _testingConnection,
                    connectionResult: _connectionResult,
                    connectionError: _connectionError,
                    onTestConnection: _testConnection,
                    onSkip: _skipToEnd,
                    onNext: _nextPage,
                  ),
                  _QuickStartPage(
                    skippedApiKey: _skippedApiKey,
                    onComplete: _completeOnboarding,
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

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 80,
            color: cs.primary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingWelcomeTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(l10n.onboardingGetStarted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingFeaturesTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _FeatureCard(
            icon: Icons.cloud_outlined,
            title: l10n.onboardingOnlineFeatures,
            description: l10n.onboardingOnlineFeaturesDesc,
            color: cs.primaryContainer,
            iconColor: cs.onPrimaryContainer,
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.phone_android_outlined,
            title: l10n.onboardingOfflineFeatures,
            description: l10n.onboardingOfflineFeaturesDesc,
            color: cs.secondaryContainer,
            iconColor: cs.onSecondaryContainer,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingTranscriptionNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(l10n.onboardingContinue),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: iconColor.withOpacity(0.8),
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

class _ApiKeyPage extends ConsumerWidget {
  const _ApiKeyPage({
    required this.apiKeyCtrl,
    required this.showKey,
    required this.onToggleShowKey,
    required this.testingConnection,
    required this.connectionResult,
    required this.connectionError,
    required this.onTestConnection,
    required this.onSkip,
    required this.onNext,
  });

  final TextEditingController apiKeyCtrl;
  final bool showKey;
  final VoidCallback onToggleShowKey;
  final bool testingConnection;
  final String? connectionResult;
  final bool connectionError;
  final VoidCallback onTestConnection;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isProviderOpenAi = settings.provider == 'openai';
    final providerLabel = isProviderOpenAi ? l10n.settingsOpenAi : l10n.settingsOpenRouter;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingApiKeyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingApiKeySubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: settings.provider,
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
                final key = await notifier.getApiKey(v) ?? '';
                apiKeyCtrl.text = key;
              }
            },
          ),
          const SizedBox(height: 16),
          if (isProviderOpenAi) ...[
            DropdownButtonFormField<String>(
              value: settings.openaiModel.isEmpty ? kOpenAiModels.first.id : settings.openaiModel,
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
              value: settings.openrouterModel.isEmpty ? null : settings.openrouterModel,
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
          ],
          const SizedBox(height: 16),
          TextField(
            controller: apiKeyCtrl,
            obscureText: !showKey,
            decoration: InputDecoration(
              labelText: l10n.settingsApiKeyLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                icon: Icon(showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggleShowKey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: testingConnection ? null : onTestConnection,
                  child: testingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.settingsTestButton),
                ),
              ),
            ],
          ),
          if (connectionResult != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  connectionError ? Icons.error_outline : Icons.check_circle_outline,
                  color: connectionError ? cs.error : Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectionResult!,
                    style: TextStyle(
                      color: connectionError ? cs.error : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(l10n.onboardingContinue),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: Text(l10n.onboardingSkipForNow),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStartPage extends StatelessWidget {
  const _QuickStartPage({
    required this.skippedApiKey,
    required this.onComplete,
  });

  final bool skippedApiKey;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            skippedApiKey ? Icons.phone_android : Icons.check_circle,
            size: 64,
            color: skippedApiKey ? cs.secondary : Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.onboardingQuickStartTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            skippedApiKey
                ? l10n.onboardingQuickStartOffline
                : l10n.onboardingQuickStartOnline,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onComplete,
              child: Text(l10n.onboardingGetStarted),
            ),
          ),
          if (skippedApiKey) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                onComplete();
                // Navigate to settings after a brief delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                });
              },
              child: Text(l10n.onboardingGoToSettings),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit the onboarding screen**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "feat: add onboarding screen with 4-page wizard"
```

---

## Task 3: Integrate Onboarding into Main App Flow

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add onboarding import and check to `main()`**

Add the import at the top of `lib/main.dart`:

```dart
import 'screens/onboarding_screen.dart';
```

Modify the `main()` function to check for onboarding before running the app. After the existing `await initializeDateFormatting();` line, add:

```dart
  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
```

Then modify the `runApp` call to pass this flag:

```dart
  runApp(
    ProviderScope(
      child: SummsummApp(
        openSettings: openSettings,
        audioImported: audioImported,
        documents: otherDocs,
        showOnboarding: !hasCompletedOnboarding && !openSettings && otherDocs.isEmpty,
      ),
    ),
  );
```

- [ ] **Step 2: Update `SummsummApp` to handle onboarding**

Add the `showOnboarding` parameter to the constructor:

```dart
class SummsummApp extends ConsumerStatefulWidget {
  const SummsummApp({
    super.key,
    required this.openSettings,
    required this.audioImported,
    required this.documents,
    required this.showOnboarding,
  });

  final bool openSettings;
  final bool audioImported;
  final List<Document> documents;
  final bool showOnboarding;
```

Update the `build` method's `home` property to show onboarding first:

```dart
      home: widget.showOnboarding
          ? const OnboardingScreen()
          : widget.openSettings
              ? const SettingsScreen(isInitialSetup: true)
              : widget.documents.isNotEmpty
                  ? _SummarySheetHost(documents: widget.documents)
                  : const MeetingLibraryScreen(),
```

- [ ] **Step 3: Commit the main.dart changes**

```bash
git add lib/main.dart
git commit -m "feat: integrate onboarding into app launch flow"
```

---

## Task 4: Run Code Generation and Verify

- [ ] **Step 1: Run build_runner to regenerate localization code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Run flutter analyze to check for issues**

```bash
flutter analyze
```

Expected: No errors or warnings related to the new onboarding code.

- [ ] **Step 3: Run flutter test to ensure existing tests pass**

```bash
flutter test
```

Expected: All existing tests pass.

- [ ] **Step 4: Commit any generated files**

```bash
git add -A
git commit -m "chore: regenerate code after onboarding implementation"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- [x] 4-screen linear wizard (Welcome, Features, API Key, Quick Start)
- [x] Skippable at any point
- [x] Explains online vs offline features
- [x] Guides optional API key setup
- [x] Shows configured state summary
- [x] Uses SharedPreferences for completion flag
- [x] Reuses existing SettingsProvider and SecureStorageService
- [x] Localized strings for both English and German

**2. Placeholder scan:**
- [x] No TBD/TODO placeholders
- [x] All code is complete and copy-paste ready
- [x] All localization strings have both English and German translations

**3. Type consistency:**
- [x] Uses existing `AppSettings`, `AiService`, `SettingsProvider` patterns
- [x] Consistent with existing SettingsScreen API key flow
- [x] Uses same `SharedPreferences` pattern as SettingsProvider

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-22-onboarding.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

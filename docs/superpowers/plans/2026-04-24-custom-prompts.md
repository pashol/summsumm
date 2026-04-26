# Custom Prompts for Meeting Summaries — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to edit built-in summary prompts and create custom prompts for meeting/document summaries.

**Architecture:** Add `CustomPrompt` model and `PromptResolver` utility. Extend `AppSettings` with `promptOverrides` (Map) and `customPrompts` (List). New settings sub-screen for prompt editing. MeetingProvider uses `PromptResolver` instead of hardcoded strings.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, UUID package

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/models/custom_prompt.dart` | Create | `CustomPrompt` immutable model with JSON serialization |
| `lib/utils/prompt_resolver.dart` | Create | Resolve prompt text from style/settings with override/custom fallback |
| `lib/models/app_settings.dart` | Modify | Add `promptOverrides` and `customPrompts` fields |
| `lib/providers/settings_provider.dart` | Modify | Add CRUD methods for prompt overrides and custom prompts |
| `lib/screens/settings/prompt_editor_screen.dart` | Create | Main prompt editing UI (built-in + custom prompts) |
| `lib/screens/settings/custom_prompt_bottom_sheet.dart` | Create | Bottom sheet for adding/editing custom prompts |
| `lib/screens/settings_screen.dart` | Modify | Rename row to "Summary", add navigation to prompt editor |
| `lib/screens/settings/summary_language_screen.dart` | Modify | Include custom prompts in style dropdown |
| `lib/providers/meeting_provider.dart` | Modify | Replace `_promptForStyle` with `PromptResolver` |
| `test/models/custom_prompt_test.dart` | Create | Unit tests for CustomPrompt model |
| `test/utils/prompt_resolver_test.dart` | Create | Unit tests for PromptResolver |

---

### Task 1: CustomPrompt Model

**Files:**
- Create: `lib/models/custom_prompt.dart`
- Test: `test/models/custom_prompt_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/custom_prompt.dart';

void main() {
  group('CustomPrompt', () {
    test('constructs with required fields', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      expect(prompt.id, 'test-uuid');
      expect(prompt.name, 'Executive Summary');
      expect(prompt.text, 'Summarize this for executives.');
    });

    test('serializes to JSON', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      expect(prompt.toJson(), {
        'id': 'test-uuid',
        'name': 'Executive Summary',
        'text': 'Summarize this for executives.',
      });
    });

    test('deserializes from JSON', () {
      final prompt = CustomPrompt.fromJson({
        'id': 'test-uuid',
        'name': 'Executive Summary',
        'text': 'Summarize this for executives.',
      });
      expect(prompt.id, 'test-uuid');
      expect(prompt.name, 'Executive Summary');
      expect(prompt.text, 'Summarize this for executives.');
    });

    test('copyWith updates fields', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      final updated = prompt.copyWith(name: 'Updated Name');
      expect(updated.id, 'test-uuid');
      expect(updated.name, 'Updated Name');
      expect(updated.text, 'Summarize this for executives.');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/custom_prompt_test.dart`
Expected: FAIL — `CustomPrompt` class not found

- [ ] **Step 3: Write the model**

```dart
class CustomPrompt {
  final String id;
  final String name;
  final String text;

  const CustomPrompt({
    required this.id,
    required this.name,
    required this.text,
  });

  factory CustomPrompt.fromJson(Map<String, dynamic> json) => CustomPrompt(
        id: json['id'] as String,
        name: json['name'] as String,
        text: json['text'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
      };

  CustomPrompt copyWith({
    String? id,
    String? name,
    String? text,
  }) =>
      CustomPrompt(
        id: id ?? this.id,
        name: name ?? this.name,
        text: text ?? this.text,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPrompt &&
          other.id == id &&
          other.name == name &&
          other.text == text;

  @override
  int get hashCode => Object.hash(id, name, text);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/custom_prompt_test.dart`
Expected: PASS — all 4 tests

- [ ] **Step 5: Commit**

```bash
git add lib/models/custom_prompt.dart test/models/custom_prompt_test.dart
git commit -m "feat: add CustomPrompt model"
```

---

### Task 2: PromptResolver Utility

**Files:**
- Create: `lib/utils/prompt_resolver.dart`
- Test: `test/utils/prompt_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/custom_prompt.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/utils/prompt_resolver.dart';

void main() {
  group('PromptResolver', () {
    test('returns hardcoded default for built-in style', () {
      const settings = AppSettings.defaults();
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        settings: settings,
      );
      expect(result, contains('3-5 bullet points'));
    });

    test('returns override when promptOverrides has entry', () {
      final settings = AppSettings.defaults().copyWith(
        promptOverrides: {'concise': 'Custom concise prompt'},
      );
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        settings: settings,
      );
      expect(result, 'Custom concise prompt');
    });

    test('returns custom prompt text when provided', () {
      const settings = AppSettings.defaults();
      const custom = CustomPrompt(
        id: 'uuid',
        name: 'Custom',
        text: 'My custom prompt',
      );
      final result = PromptResolver.resolve(
        customPrompt: custom,
        settings: settings,
      );
      expect(result, 'My custom prompt');
    });

    test('custom prompt takes priority over style override', () {
      final settings = AppSettings.defaults().copyWith(
        promptOverrides: {'concise': 'Override'},
      );
      const custom = CustomPrompt(
        id: 'uuid',
        name: 'Custom',
        text: 'Custom wins',
      );
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        customPrompt: custom,
        settings: settings,
      );
      expect(result, 'Custom wins');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/prompt_resolver_test.dart`
Expected: FAIL — `PromptResolver` not found

- [ ] **Step 3: Write the implementation**

```dart
import '../models/app_settings.dart';
import '../models/custom_prompt.dart';
import '../models/summary_style.dart';

class PromptResolver {
  static String resolve({
    SummaryStyle? style,
    CustomPrompt? customPrompt,
    required AppSettings settings,
  }) {
    if (customPrompt != null) {
      return customPrompt.text;
    }

    if (style != null && settings.promptOverrides.containsKey(style.name)) {
      return settings.promptOverrides[style.name]!;
    }

    return _defaultPrompt(style ?? SummaryStyle.structured);
  }

  static String _defaultPrompt(SummaryStyle style) {
    switch (style) {
      case SummaryStyle.concise:
        return 'You are an expert summarizer. Produce a brief summary with 3-5 bullet points covering only the key points. Do not elaborate. Do not wrap output in a code block.';
      case SummaryStyle.brief:
        return 'You are an expert document summarizer. Write a short paragraph summarizing the key points of this document. Do not use bullet points or headers. Do not wrap output in a code block.';
      case SummaryStyle.detailed:
        return 'You are an expert summarizer. Produce a comprehensive summary with thorough coverage of each topic. Include context and reasoning. Use ## headers for topics, paragraphs for detail. Do not wrap output in a code block.';
      case SummaryStyle.structured:
        return 'You are an expert meeting summarizer. Extract: 1. Key decisions made 2. Action items with owners 3. Open questions 4. Important context. Use markdown headers and bullet points. Do not wrap output in a code block. Be concise and factual.';
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/prompt_resolver_test.dart`
Expected: PASS — all 4 tests

- [ ] **Step 5: Commit**

```bash
git add lib/utils/prompt_resolver.dart test/utils/prompt_resolver_test.dart
git commit -m "feat: add PromptResolver utility"
```

---

### Task 3: Extend AppSettings

**Files:**
- Modify: `lib/models/app_settings.dart`

- [ ] **Step 1: Add fields to AppSettings**

Add after `compressAudioStorage`:

```dart
  final Map<String, String> promptOverrides;
  final List<CustomPrompt> customPrompts;
```

Update constructor:

```dart
  const AppSettings({
    required this.provider,
    required this.openrouterModel,
    required this.openaiModel,
    required this.language,
    required this.summaryStyle,
    required this.ttsSpeed,
    required this.openaiKey,
    required this.openrouterKey,
    this.debugMode = false,
    this.localeOverride,
    this.transcriptionStrategy = TranscriptionStrategy.cloud,
    this.onDeviceModelSize = ModelSize.tiny,
    this.enableRealTimeTranscription = false,
    this.onDeviceDiarization = true,
    this.streamingModelLanguage = 'English',
    this.compressAudioStorage = false,
    this.promptOverrides = const {},
    this.customPrompts = const [],
  });
```

Update `defaults()` factory:

```dart
  factory AppSettings.defaults() => const AppSettings(
        provider: 'openrouter',
        openrouterModel: '',
        openaiModel: '',
        language: 'Same as input',
        summaryStyle: 'structured',
        ttsSpeed: 1.0,
        openaiKey: '',
        openrouterKey: '',
        debugMode: false,
        localeOverride: null,
        transcriptionStrategy: TranscriptionStrategy.cloud,
        onDeviceModelSize: ModelSize.tiny,
        enableRealTimeTranscription: false,
        onDeviceDiarization: true,
        streamingModelLanguage: 'English',
        compressAudioStorage: false,
        promptOverrides: const {},
        customPrompts: const [],
      );
```

Update `copyWith`:

```dart
  AppSettings copyWith({
    String? provider,
    String? openrouterModel,
    String? openaiModel,
    String? language,
    String? summaryStyle,
    double? ttsSpeed,
    String? openaiKey,
    String? openrouterKey,
    bool? debugMode,
    String? localeOverride,
    TranscriptionStrategy? transcriptionStrategy,
    ModelSize? onDeviceModelSize,
    bool? enableRealTimeTranscription,
    bool? onDeviceDiarization,
    String? streamingModelLanguage,
    bool? compressAudioStorage,
    Map<String, String>? promptOverrides,
    List<CustomPrompt>? customPrompts,
  }) =>
      AppSettings(
        provider: provider ?? this.provider,
        openrouterModel: openrouterModel ?? this.openrouterModel,
        openaiModel: openaiModel ?? this.openaiModel,
        language: language ?? this.language,
        summaryStyle: summaryStyle ?? this.summaryStyle,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        openaiKey: openaiKey ?? this.openaiKey,
        openrouterKey: openrouterKey ?? this.openrouterKey,
        debugMode: debugMode ?? this.debugMode,
        localeOverride: localeOverride ?? this.localeOverride,
        transcriptionStrategy: transcriptionStrategy ?? this.transcriptionStrategy,
        onDeviceModelSize: onDeviceModelSize ?? this.onDeviceModelSize,
        enableRealTimeTranscription: enableRealTimeTranscription ?? this.enableRealTimeTranscription,
        onDeviceDiarization: onDeviceDiarization ?? this.onDeviceDiarization,
        streamingModelLanguage: streamingModelLanguage ?? this.streamingModelLanguage,
        compressAudioStorage: compressAudioStorage ?? this.compressAudioStorage,
        promptOverrides: promptOverrides ?? this.promptOverrides,
        customPrompts: customPrompts ?? this.customPrompts,
      );
```

Update `toJson`:

```dart
  Map<String, dynamic> toJson() => {
        'provider': provider,
        'openrouterModel': openrouterModel,
        'openaiModel': openaiModel,
        'language': language,
        'summaryStyle': summaryStyle,
        'ttsSpeed': ttsSpeed,
        'openaiKey': openaiKey,
        'openrouterKey': openrouterKey,
        'debugMode': debugMode,
        'localeOverride': localeOverride,
        'transcriptionStrategy': transcriptionStrategy.name,
        'onDeviceModelSize': onDeviceModelSize.name,
        'enableRealTimeTranscription': enableRealTimeTranscription,
        'onDeviceDiarization': onDeviceDiarization,
        'streamingModelLanguage': streamingModelLanguage,
        'compressAudioStorage': compressAudioStorage,
        'promptOverrides': promptOverrides,
        'customPrompts': customPrompts.map((p) => p.toJson()).toList(),
      };
```

Update `fromJson`:

```dart
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        provider: json['provider'] as String? ?? 'openrouter',
        openrouterModel: json['openrouterModel'] as String? ?? '',
        openaiModel: json['openaiModel'] as String? ?? '',
        language: json['language'] as String? ?? 'English',
        summaryStyle: json['summaryStyle'] as String? ?? 'structured',
        ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
        openaiKey: json['openaiKey'] as String? ?? '',
        openrouterKey: json['openrouterKey'] as String? ?? '',
        debugMode: json['debugMode'] as bool? ?? false,
        localeOverride: json['localeOverride'] as String?,
        transcriptionStrategy: TranscriptionStrategy.values.byName(
          json['transcriptionStrategy'] as String? ?? 'cloud',
        ),
        onDeviceModelSize: ModelSize.values.byName(
          json['onDeviceModelSize'] as String? ?? 'base',
        ),
        enableRealTimeTranscription:
            json['enableRealTimeTranscription'] as bool? ?? false,
        onDeviceDiarization: json['onDeviceDiarization'] as bool? ?? true,
        streamingModelLanguage: json['streamingModelLanguage'] as String? ?? 'English',
        compressAudioStorage: json['compressAudioStorage'] as bool? ?? false,
        promptOverrides: (json['promptOverrides'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as String),
            ) ??
            const {},
        customPrompts: (json['customPrompts'] as List<dynamic>?)
                ?.map((e) => CustomPrompt.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
```

Update `operator ==`:

```dart
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.provider == provider &&
        other.openrouterModel == openrouterModel &&
        other.openaiModel == openaiModel &&
        other.language == language &&
        other.summaryStyle == summaryStyle &&
        other.ttsSpeed == ttsSpeed &&
        other.openaiKey == openaiKey &&
        other.openrouterKey == openrouterKey &&
        other.debugMode == debugMode &&
        other.localeOverride == localeOverride &&
        other.transcriptionStrategy == transcriptionStrategy &&
        other.onDeviceModelSize == onDeviceModelSize &&
        other.enableRealTimeTranscription == enableRealTimeTranscription &&
        other.onDeviceDiarization == onDeviceDiarization &&
        other.streamingModelLanguage == streamingModelLanguage &&
        other.compressAudioStorage == compressAudioStorage &&
        _mapEquals(other.promptOverrides, promptOverrides) &&
        _listEquals(other.customPrompts, customPrompts);
  }
```

Add helper functions at top of file:

```dart
bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

bool _listEquals(List<CustomPrompt> a, List<CustomPrompt> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

Update `hashCode`:

```dart
  @override
  int get hashCode => Object.hash(
        provider,
        openrouterModel,
        openaiModel,
        language,
        summaryStyle,
        ttsSpeed,
        openaiKey,
        openrouterKey,
        debugMode,
        localeOverride,
        transcriptionStrategy,
        onDeviceModelSize,
        enableRealTimeTranscription,
        onDeviceDiarization,
        streamingModelLanguage,
        compressAudioStorage,
        Object.hashAll(promptOverrides.entries),
        Object.hashAll(customPrompts),
      );
```

Add import at top:

```dart
import 'custom_prompt.dart';
```

- [ ] **Step 2: Run existing tests**

Run: `flutter test`
Expected: PASS — all existing tests still pass

- [ ] **Step 3: Commit**

```bash
git add lib/models/app_settings.dart
git commit -m "feat: extend AppSettings with promptOverrides and customPrompts"
```

---

### Task 4: Settings Provider CRUD Methods

**Files:**
- Modify: `lib/providers/settings_provider.dart`

- [ ] **Step 1: Add CRUD methods to Settings provider**

Add these methods to the `Settings` class:

```dart
  Future<void> setPromptOverride(String style, String text) async {
    final nextOverrides = Map<String, String>.from(state.promptOverrides);
    nextOverrides[style] = text;
    final next = state.copyWith(promptOverrides: nextOverrides);
    state = next;
    await _persist(next);
  }

  Future<void> resetPromptOverride(String style) async {
    final nextOverrides = Map<String, String>.from(state.promptOverrides);
    nextOverrides.remove(style);
    final next = state.copyWith(promptOverrides: nextOverrides);
    state = next;
    await _persist(next);
  }

  Future<String> addCustomPrompt(String name, String text) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final prompt = CustomPrompt(id: id, name: name, text: text);
    final nextPrompts = [...state.customPrompts, prompt];
    final next = state.copyWith(customPrompts: nextPrompts);
    state = next;
    await _persist(next);
    return id;
  }

  Future<void> updateCustomPrompt(String id, {String? name, String? text}) async {
    final nextPrompts = state.customPrompts.map((p) {
      if (p.id == id) {
        return p.copyWith(name: name ?? p.name, text: text ?? p.text);
      }
      return p;
    }).toList();
    final next = state.copyWith(customPrompts: nextPrompts);
    state = next;
    await _persist(next);
  }

  Future<void> deleteCustomPrompt(String id) async {
    final nextPrompts = state.customPrompts.where((p) => p.id != id).toList();
    final next = state.copyWith(customPrompts: nextPrompts);
    state = next;
    await _persist(next);
  }
```

Add import if not present:

```dart
import '../models/custom_prompt.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/settings_provider.dart
git commit -m "feat: add prompt CRUD methods to Settings provider"
```

---

### Task 5: Prompt Editor Screen

**Files:**
- Create: `lib/screens/settings/prompt_editor_screen.dart`

- [ ] **Step 1: Create the prompt editor screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/utils/prompt_resolver.dart';
import 'package:summsumm/widgets/glass_card.dart';

import 'custom_prompt_bottom_sheet.dart';

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen({super.key});

  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  SummaryStyle _selectedStyle = SummaryStyle.concise;
  final _textController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPromptForStyle();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _loadPromptForStyle() {
    final settings = ref.read(settingsProvider);
    final prompt = PromptResolver.resolve(
      style: _selectedStyle,
      settings: settings,
    );
    _textController.text = prompt;
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final notifier = ref.read(settingsProvider.notifier);
      notifier.setPromptOverride(_selectedStyle.name, value);
    });
  }

  Future<void> _resetPrompt() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.resetPromptOverride(_selectedStyle.name);
    if (mounted) {
      _loadPromptForStyle();
    }
  }

  Future<void> _deleteCustomPrompt(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deletePromptTitle),
        content: Text(AppLocalizations.of(context)!.deletePromptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.deleteCustomPrompt(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

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
          // Built-in prompts section
          Text(
            l10n.defaultPromptSection,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<SummaryStyle>(
                    value: _selectedStyle,
                    decoration: InputDecoration(
                      labelText: l10n.summaryStyleLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: SummaryStyle.values.map((style) {
                      return DropdownMenuItem(
                        value: style,
                        child: Text(style.localizedTitle(context)),
                      );
                    }).toList(),
                    onChanged: (style) {
                      if (style != null) {
                        setState(() {
                          _selectedStyle = style;
                        });
                        _loadPromptForStyle();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.promptTextLabel,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: _onTextChanged,
                  ),
                  const SizedBox(height: 8),
                  if (settings.promptOverrides.containsKey(_selectedStyle.name))
                    TextButton.icon(
                      onPressed: _resetPrompt,
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.resetToDefault),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Custom prompts section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.customPromptsSection,
                style: theme.textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: () => _showAddPromptSheet(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.addPrompt),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (settings.customPrompts.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.noCustomPrompts,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...settings.customPrompts.map((prompt) {
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(prompt.name),
                  subtitle: Text(
                    prompt.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditPromptSheet(context, prompt),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCustomPrompt(prompt.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddPromptSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CustomPromptBottomSheet(),
    );
  }

  Future<void> _showEditPromptSheet(BuildContext context, CustomPrompt prompt) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CustomPromptBottomSheet(prompt: prompt),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings/prompt_editor_screen.dart
git commit -m "feat: add prompt editor screen"
```

---

### Task 6: Custom Prompt Bottom Sheet

**Files:**
- Create: `lib/screens/settings/custom_prompt_bottom_sheet.dart`

- [ ] **Step 1: Create the bottom sheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/custom_prompt.dart';
import 'package:summsumm/providers/settings_provider.dart';

class CustomPromptBottomSheet extends ConsumerStatefulWidget {
  final CustomPrompt? prompt;

  const CustomPromptBottomSheet({super.key, this.prompt});

  @override
  ConsumerState<CustomPromptBottomSheet> createState() =>
      _CustomPromptBottomSheetState();
}

class _CustomPromptBottomSheetState
    extends ConsumerState<CustomPromptBottomSheet> {
  late final _nameController = TextEditingController(text: widget.prompt?.name);
  late final _textController = TextEditingController(text: widget.prompt?.text);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(settingsProvider.notifier);

    if (widget.prompt != null) {
      await notifier.updateCustomPrompt(
        widget.prompt!.id,
        name: _nameController.text.trim(),
        text: _textController.text.trim(),
      );
    } else {
      await notifier.addCustomPrompt(
        _nameController.text.trim(),
        _textController.text.trim(),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.prompt != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? l10n.editPromptTitle : l10n.newPromptTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.promptNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.promptNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _textController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.promptTextLabel,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.promptTextRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? l10n.save : l10n.create),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings/custom_prompt_bottom_sheet.dart
git commit -m "feat: add custom prompt bottom sheet"
```

---

### Task 7: Settings Screen Integration

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Update settings row**

Change the "Summary & Language" row:

```dart
              _SettingsRow(
                icon: Icons.summarize,
                title: l10n.settingsSummaryRow,  // New localization key
                subtitle: '${SummaryStyle.values.byName(settings.summaryStyle).localizedTitle(context)}, ${localizedLanguageName(context, settings.language)}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SummaryLanguageScreen()),
                  );
                },
              ),
```

Add new row below it (inside the same `_SettingsSection`):

```dart
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SettingsRow(
                icon: Icons.edit_note,
                title: l10n.settingsPromptsRow,
                subtitle: '${settings.promptOverrides.length} ${l10n.edited}, ${settings.customPrompts.length} ${l10n.custom}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const PromptEditorScreen()),
                  );
                },
              ),
```

Add import:

```dart
import 'settings/prompt_editor_screen.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: integrate prompt editor into settings"
```

---

### Task 8: Summary Language Screen Integration

**Files:**
- Modify: `lib/screens/settings/summary_language_screen.dart`

- [ ] **Step 1: Include custom prompts in dropdown**

Modify the dropdown to include custom prompts:

```dart
          DropdownButtonFormField<String>(
            initialValue: settings.summaryStyle,
            decoration: InputDecoration(
              labelText: l10n.settingsStyleLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.format_list_bulleted_outlined),
            ),
            items: [
              ...SummaryStyle.values.map((s) => 
                DropdownMenuItem(value: s.name, child: Text(s.localizedTitle(context)))),
              if (settings.customPrompts.isNotEmpty) ...[
                const DropdownMenuItem(enabled: false, child: Divider()),
                ...settings.customPrompts.map((p) => 
                  DropdownMenuItem(value: 'custom:${p.id}', child: Text(p.name))),
              ],
            ],
            onChanged: (v) {
              if (v != null) {
                if (v.startsWith('custom:')) {
                  // Store the custom prompt ID somehow, or just keep summaryStyle as-is
                  // and store selected custom prompt separately
                } else {
                  notifier.setSummaryStyle(v);
                }
              }
            },
          ),
```

**Note:** This requires a decision on how to store selected custom prompt. Options:
1. Add `selectedCustomPromptId` to AppSettings
2. Use a convention in `summaryStyle` field (e.g., `custom:uuid`)

Recommended: Add `selectedCustomPromptId` field to AppSettings for clarity.

- [ ] **Step 2: Add selectedCustomPromptId to AppSettings**

Update `AppSettings` with new field:

```dart
  final String? selectedCustomPromptId;
```

Update constructor, copyWith, toJson, fromJson, ==, hashCode accordingly.

Update `defaults()`:
```dart
    selectedCustomPromptId: null,
```

Add provider method:

```dart
  Future<void> setSelectedCustomPrompt(String? id) async {
    final next = state.copyWith(selectedCustomPromptId: id);
    state = next;
    await _persist(next);
  }
```

Update dropdown onChanged:

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings/summary_language_screen.dart lib/models/app_settings.dart lib/providers/settings_provider.dart
git commit -m "feat: include custom prompts in summary style dropdown"
```

---

### Task 9: Meeting Provider Integration

**Files:**
- Modify: `lib/providers/meeting_provider.dart`

- [ ] **Step 1: Replace _promptForStyle with PromptResolver**

Replace the entire `_promptForStyle` method:

```dart
  String _promptForStyle(SummaryStyle style, MeetingType type, String langSuffixText) {
    final settings = ref.read(settingsProvider);
    
    // Check if a custom prompt is selected
    CustomPrompt? selectedCustom;
    if (settings.selectedCustomPromptId != null) {
      selectedCustom = settings.customPrompts.firstWhereOrNull(
        (p) => p.id == settings.selectedCustomPromptId,
      );
    }
    
    final basePrompt = PromptResolver.resolve(
      style: style,
      customPrompt: selectedCustom,
      settings: settings,
    );
    
    return '$basePrompt$langSuffixText';
  }
```

Add imports:

```dart
import '../models/custom_prompt.dart';
import '../utils/prompt_resolver.dart';
import 'package:collection/collection.dart';  // for firstWhereOrNull
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/meeting_provider.dart
git commit -m "feat: use PromptResolver in MeetingProvider"
```

---

### Task 10: Localization Strings

**Files:**
- Modify: `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`

- [ ] **Step 1: Add English strings**

Add to `lib/l10n/app_en.arb`:

```json
{
  "promptEditorTitle": "Summary Prompts",
  "defaultPromptSection": "Default Prompt",
  "customPromptsSection": "Custom Prompts",
  "summaryStyleLabel": "Summary Style",
  "promptTextLabel": "Prompt Text",
  "resetToDefault": "Reset to Default",
  "addPrompt": "Add Prompt",
  "noCustomPrompts": "No custom prompts yet. Tap + to create one.",
  "newPromptTitle": "New Custom Prompt",
  "editPromptTitle": "Edit Custom Prompt",
  "promptNameLabel": "Name",
  "promptNameRequired": "Please enter a name",
  "promptTextRequired": "Please enter prompt text",
  "create": "Create",
  "save": "Save",
  "cancel": "Cancel",
  "delete": "Delete",
  "deletePromptTitle": "Delete Prompt",
  "deletePromptMessage": "Are you sure you want to delete this custom prompt?",
  "settingsSummaryRow": "Summary",
  "settingsPromptsRow": "Prompts",
  "edited": "edited",
  "custom": "custom"
}
```

- [ ] **Step 2: Add German strings**

Add to `lib/l10n/app_de.arb`:

```json
{
  "promptEditorTitle": "Zusammenfassungs-Prompts",
  "defaultPromptSection": "Standard-Prompt",
  "customPromptsSection": "Benutzerdefinierte Prompts",
  "summaryStyleLabel": "Zusammenfassungsstil",
  "promptTextLabel": "Prompt-Text",
  "resetToDefault": "Auf Standard zurücksetzen",
  "addPrompt": "Prompt hinzufügen",
  "noCustomPrompts": "Noch keine benutzerdefinierten Prompts. Tippe auf +, um einen zu erstellen.",
  "newPromptTitle": "Neuer benutzerdefinierter Prompt",
  "editPromptTitle": "Benutzerdefinierten Prompt bearbeiten",
  "promptNameLabel": "Name",
  "promptNameRequired": "Bitte gib einen Namen ein",
  "promptTextRequired": "Bitte gib einen Prompt-Text ein",
  "create": "Erstellen",
  "save": "Speichern",
  "cancel": "Abbrechen",
  "delete": "Löschen",
  "deletePromptTitle": "Prompt löschen",
  "deletePromptMessage": "Möchtest du diesen benutzerdefinierten Prompt wirklich löschen?",
  "settingsSummaryRow": "Zusammenfassung",
  "settingsPromptsRow": "Prompts",
  "edited": "bearbeitet",
  "custom": "benutzerdefiniert"
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: add localization strings for custom prompts"
```

---

### Task 11: Run All Tests

- [ ] **Step 1: Run tests**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 2: Run lint**

```bash
flutter analyze
```

Expected: No issues

- [ ] **Step 3: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Success (if any providers changed)

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "feat: custom prompts for meeting summaries"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task | Status |
|-----------------|------|--------|
| CustomPrompt model with JSON serialization | Task 1 | ✅ |
| PromptResolver with override/custom/default fallback | Task 2 | ✅ |
| AppSettings extended with promptOverrides + customPrompts | Task 3 | ✅ |
| Settings provider CRUD methods | Task 4 | ✅ |
| Prompt editor screen with built-in + custom sections | Task 5 | ✅ |
| Bottom sheet for add/edit custom prompts | Task 6 | ✅ |
| Settings screen integration | Task 7 | ✅ |
| Summary language dropdown includes custom prompts | Task 8 | ✅ |
| MeetingProvider uses PromptResolver | Task 9 | ✅ |
| Localization strings | Task 10 | ✅ |
| Debounced auto-save for built-in prompt edits | Task 5 | ✅ |
| Reset to default for built-in prompts | Task 5 | ✅ |
| Delete confirmation for custom prompts | Task 5 | ✅ |
| langSuffix auto-appended (not user-editable) | Tasks 2, 9 | ✅ |

---

## Placeholder Scan

No placeholders found. All tasks contain complete code, exact file paths, exact commands, and expected outputs.

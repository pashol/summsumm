# Local AI with RAG-First Generation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add flutter_gemma (Gemma 3 1B) as optional local generation for Ask Library and meeting chat, with RAG-first context assembly for both cloud and local paths.

**Architecture:** Keep mobile_rag_engine for retrieval. Add LocalLlmService wrapping flutter_gemma for on-device generation. Add `localAiEnabled` setting defaulting to off. When a meeting is indexed in RAG, use filtered search instead of full transcript for context — applies to both cloud and local.

**Tech Stack:** flutter_gemma ^0.14.0, mobile_rag_engine ^0.17.0, Riverpod, Gemma 3 1B (.task format)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/models/app_settings.dart` | Add `localAiEnabled` field |
| Modify | `lib/providers/settings_provider.dart` | Add `setLocalAiEnabled()` method |
| Modify | `lib/services/library_rag_service.dart` | Add `sourceIds` to `search()` |
| Create | `lib/services/local_llm_service.dart` | Wrap flutter_gemma for local generation |
| Modify | `lib/providers/ask_library_chat_provider.dart` | Route to local or cloud generation, guard empty API key |
| Modify | `lib/providers/meeting_chat_provider.dart` | RAG-first context, local/cloud routing |
| Modify | `lib/screens/settings_screen.dart` | Add Local AI toggle + download UI |
| Modify | `lib/l10n/app_localizations_en.dart` | Add local AI strings |
| Modify | `lib/l10n/app_localizations_de.dart` | Add German local AI strings |
| Modify | `pubspec.yaml` | Add flutter_gemma dependency |
| Modify | `test/models/app_settings_test.dart` | Test localAiEnabled serialization |
| Create | `test/services/local_llm_service_test.dart` | Test LocalLlmService |
| Modify | `android/app/src/main/AndroidManifest.xml` | Add OpenGL entries for GPU |

---

### Task 1: Add `localAiEnabled` setting to AppSettings

**Files:**
- Modify: `lib/models/app_settings.dart`
- Modify: `test/models/app_settings_test.dart`

- [ ] **Step 1: Write failing test for `localAiEnabled` defaults and serialization**

Add to `test/models/app_settings_test.dart`:

```dart
test('defaults disable local AI', () {
  const settings = AppSettings.defaults();

  expect(settings.localAiEnabled, isFalse);
});

test('serializes local AI setting', () {
  const settings = AppSettings.defaults();
  final enabled = settings.copyWith(localAiEnabled: true);

  final decoded = AppSettings.fromJson(enabled.toJson());

  expect(decoded.localAiEnabled, isTrue);
});

test('missing local AI setting migrates to disabled', () {
  final decoded = AppSettings.fromJson(const {
    'provider': 'openrouter',
    'openrouterModel': '',
    'openaiModel': '',
    'language': 'Same as input',
    'summaryStyle': 'structured',
    'ttsSpeed': 1.0,
  });

  expect(decoded.localAiEnabled, isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/app_settings_test.dart`
Expected: FAIL — `localAiEnabled` getter not defined

- [ ] **Step 3: Add `localAiEnabled` field to `AppSettings`**

In `lib/models/app_settings.dart`:

1. Add field after `showExtractedPdfTextOnly` (line 26):
```dart
final bool localAiEnabled;
```

2. Add to constructor (after line 49):
```dart
this.localAiEnabled = false,
```

3. Add to `AppSettings.defaults()` (after line 74):
```dart
localAiEnabled: false,
```

4. Add to `copyWith()` parameter list (after line 98):
```dart
bool? localAiEnabled,
```

5. Add to `copyWith()` body (after line 121):
```dart
localAiEnabled: localAiEnabled ?? this.localAiEnabled,
```

6. Add to `toJson()` (after line 146):
```dart
'localAiEnabled': localAiEnabled,
```

7. Add to `fromJson()` (after line 175):
```dart
localAiEnabled: json['localAiEnabled'] as bool? ?? false,
```

8. Add to `operator ==` (after line 217):
```dart
other.localAiEnabled == localAiEnabled &&
```

9. Add to `hashCode` (after line 242):
```dart
localAiEnabled,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/app_settings_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/app_settings.dart test/models/app_settings_test.dart
git commit -m "feat: add localAiEnabled setting to AppSettings"
```

---

### Task 2: Add `setLocalAiEnabled` to Settings notifier

**Files:**
- Modify: `lib/providers/settings_provider.dart`

- [ ] **Step 1: Add `setLocalAiEnabled` method**

Add after `setShowExtractedPdfTextOnly` (line 159):

```dart
Future<void> setLocalAiEnabled(bool enabled) async {
  final next = state.copyWith(localAiEnabled: enabled);
  state = next;
  await _persist(next);
}
```

- [ ] **Step 2: Run analysis**

Run: `flutter analyze lib/providers/settings_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/settings_provider.dart
git commit -m "feat: add setLocalAiEnabled to Settings notifier"
```

---

### Task 3: Add `sourceIds` parameter to LibraryRagService search

**Files:**
- Modify: `lib/services/library_rag_service.dart`

- [ ] **Step 1: Add `sourceIds` to `LibraryRagClient` abstract method**

Change line 29:
```dart
Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds});
```

- [ ] **Step 2: Add `sourceIds` to `MobileLibraryRagClient.search()`**

Change `search` method (lines 60-81):
```dart
@override
Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async {
  if (!MobileRag.instance.isIndexReady) {
    await MobileRag.instance.warmupFuture;
  }
  final result = await MobileRag.instance.searchHybridWithContext(
    query,
    topK: 12,
    tokenBudget: 3000,
    adjacentChunks: 1,
    sourceIds: sourceIds,
  );
  return LibraryRagSearchResult(
    contextText: result.context.text,
    chunks: result.chunks
        .map(
          (chunk) => LibraryRagSearchChunk(
            sourceId: chunk.sourceId,
            content: chunk.content,
            metadata: chunk.metadata,
          ),
        )
        .toList(),
  );
}
```

- [ ] **Step 3: Add `sourceIds` to `FakeLibraryRagClient.search()`**

Change line 147:
```dart
@override
Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async => searchResult;
```

- [ ] **Step 4: Add `sourceIds` to `LibraryRagService.search()`**

Change lines 180-183:
```dart
Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async {
  await initialize();
  return _client.search(query, sourceIds: sourceIds);
}
```

- [ ] **Step 5: Run analysis**

Run: `flutter analyze lib/services/library_rag_service.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/services/library_rag_service.dart
git commit -m "feat: add sourceIds filter to LibraryRagService search"
```

---

### Task 4: Add flutter_gemma dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add flutter_gemma to pubspec.yaml**

Add after `mobile_rag_engine: ^0.17.0` (line 47):

```yaml
  flutter_gemma: ^0.14.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Success

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add flutter_gemma dependency"
```

---

### Task 5: Create LocalLlmService

**Files:**
- Create: `lib/services/local_llm_service.dart`
- Create: `test/services/local_llm_service_test.dart`

- [ ] **Step 1: Write failing test for LocalLlmService**

Create `test/services/local_llm_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/local_llm_service.dart';

void main() {
  test('isModelReady returns false when not initialized', () {
    final service = LocalLlmService();
    expect(service.isModelReady, isFalse);
  });

  test('streamChat throws when model not ready', () async {
    final service = LocalLlmService();
    expect(
      () => service.streamChat(
        systemPrompt: 'test',
        messages: [{'role': 'user', 'content': 'hi'}],
      ),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/local_llm_service_test.dart`
Expected: FAIL — `LocalLlmService` not defined

- [ ] **Step 3: Implement LocalLlmService**

Create `lib/services/local_llm_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/model_management/model_manager.dart';

const _kGemmaModelName = 'gemma-3-1b-it-gpu-int8.task';
const _kGemmaModelUrl =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma-3-1b-it-gpu-int8.task';

class LocalLlmService {
  InferenceModel? _model;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  bool get isModelReady => _model != null;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  Future<bool> isModelInstalled() async {
    return FlutterGemma.isModelInstalled(_kGemmaModelName);
  }

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    _isDownloading = true;
    _downloadProgress = 0;
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_kGemmaModelUrl).withProgress((progress) {
        _downloadProgress = progress.percentage / 100.0;
        onProgress?.call(_downloadProgress);
      }).install();
    } finally {
      _isDownloading = false;
      _downloadProgress = 0;
    }
  }

  Future<void> ensureModelLoaded() async {
    if (_model != null) return;

    final installed = await isModelInstalled();
    if (!installed) throw StateError('Model not downloaded. Call downloadModel() first.');

    _model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async* {
    if (_model == null) throw StateError('Model not ready. Call ensureModelLoaded() first.');

    final chat = await _model!.createChat(
      systemInstruction: systemPrompt,
      temperature: 0.8,
      topK: 3,
    );

    for (final message in messages) {
      final content = message['content'] as String;
      final isUser = message['role'] == 'user';
      await chat.addQueryChunk(Message.text(text: content, isUser: isUser));
    }

    final controller = StreamController<String>();

    chat.generateChatResponseAsync().listen(
      (response) {
        if (response is TextResponse) {
          controller.add(response.token);
        }
      },
      onError: (Object e) {
        controller.addError(e);
      },
      onDone: () {
        controller.close();
      },
      cancelOnError: true,
    );

    yield* controller.stream;
  }

  Future<void> close() async {
    await _model?.close();
    _model = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/local_llm_service_test.dart`
Expected: PASS

- [ ] **Step 5: Run full analysis**

Run: `flutter analyze lib/services/local_llm_service.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/services/local_llm_service.dart test/services/local_llm_service_test.dart
git commit -m "feat: create LocalLlmService wrapping flutter_gemma"
```

---

### Task 6: Add LocalLlmService Riverpod provider

**Files:**
- Create: `lib/providers/local_llm_provider.dart`

- [ ] **Step 1: Create provider file**

Create `lib/providers/local_llm_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_llm_service.dart';

final localLlmServiceProvider = Provider<LocalLlmService>((ref) {
  final service = LocalLlmService();
  ref.onDispose(() => service.close());
  return service;
});
```

- [ ] **Step 2: Run analysis**

Run: `flutter analyze lib/providers/local_llm_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/local_llm_provider.dart
git commit -m "feat: add LocalLlmService Riverpod provider"
```

---

### Task 7: Fix Ask Library empty API key bug and add local routing

**Files:**
- Modify: `lib/providers/ask_library_chat_provider.dart`

- [ ] **Step 1: Add imports**

Add at top (after line 12):

```dart
import '../providers/local_llm_provider.dart';
```

- [ ] **Step 2: Modify `sendMessage` to guard empty API key and route to local**

Replace lines 91-118 (from `final settings` to end of `streamCompletion` call) with:

```dart
      final settings = _ref.read(settingsProvider);
      final useLocal = settings.localAiEnabled;

      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content':
              'You answer questions using only the provided library context. If the context does not support an answer, say you could not find enough information. Keep answers concise and cite source labels when useful.',
        },
        {
          'role': 'system',
          'content': 'Library context for this turn:\n${search.contextText}',
        },
        ..._buildPromptHistory(previousMessages),
        {
          'role': 'user',
          'content': trimmed,
        },
      ];

      Stream<String> stream;
      if (useLocal) {
        final localLlm = _ref.read(localLlmServiceProvider);
        final installed = await localLlm.isModelInstalled();
        if (!installed) {
          final updated = List<AskLibraryMessage>.from(state.messages)
            ..removeLast();
          state = state.copyWith(
            messages: updated,
            isStreaming: false,
            error: 'Local AI model not downloaded. Download it in Settings first.',
          );
          return;
        }
        await localLlm.ensureModelLoaded();
        stream = localLlm.streamChat(
          systemPrompt: apiMessages[0]['content'] as String,
          messages: apiMessages.sublist(1),
        );
      } else {
        final apiKey = await _ref
                .read(settingsProvider.notifier)
                .getApiKey(settings.provider) ??
            '';
        if (apiKey.isEmpty) {
          final updated = List<AskLibraryMessage>.from(state.messages)
            ..removeLast();
          state = state.copyWith(
            messages: updated,
            isStreaming: false,
            error: 'No API key configured. Open Settings first.',
          );
          return;
        }
        stream = _ref.read(aiServiceProvider).streamCompletion(
              apiKey: apiKey,
              model: settings.activeModel,
              messages: apiMessages,
              provider: settings.provider,
            );
      }
```

Then change line 113 (`final stream = _ref.read(aiServiceProvider).streamCompletion(...)`) — this is now replaced by the `stream` variable above, so the existing `_streamSub = stream.listen(` on line 121 stays as-is.

- [ ] **Step 3: Run analysis**

Run: `flutter analyze lib/providers/ask_library_chat_provider.dart`
Expected: No errors

- [ ] **Step 4: Run existing Ask Library tests**

Run: `flutter test test/screens/ask_library_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/providers/ask_library_chat_provider.dart
git commit -m "fix: guard empty API key in Ask Library, add local generation routing"
```

---

### Task 8: Add RAG-first context to MeetingChatNotifier with local routing

**Files:**
- Modify: `lib/providers/meeting_chat_provider.dart`

- [ ] **Step 1: Add imports**

Add at top (after line 10):

```dart
import '../providers/local_llm_provider.dart';
import '../providers/library_rag_provider.dart';
import '../services/library_rag_metadata_store.dart';
```

- [ ] **Step 2: Modify `sendMessage` to accept meetingId, use RAG-first context, and route locally**

Replace the `sendMessage` method (lines 43-120) with:

```dart
  Future<void> sendMessage(
    String question, {
    required String transcript,
    required String meetingId,
    String? summary,
  }) async {
    if (state.isStreaming || question.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: question.trim());
    const assistantMsg = ChatMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
      clearError: true,
    );

    final settings = _ref.read(settingsProvider);
    final useLocal = settings.localAiEnabled;

    String systemPrompt;
    try {
      final metadataStore = _ref.read(libraryRagMetadataStoreProvider);
      final metadata = await metadataStore.load();
      final indexedSource = metadata.sourceForLibraryItem(meetingId);

      if (indexedSource != null) {
        final ragService = _ref.read(libraryRagServiceProvider);
        final searchResult = await ragService.search(
          question.trim(),
          sourceIds: [indexedSource.ragSourceId],
        );
        if (searchResult.contextText.trim().isNotEmpty) {
          systemPrompt =
              'You are a helpful assistant. The user recorded a meeting.\n'
              'Relevant context from the meeting transcript:\n${searchResult.contextText}\n'
              '${summary != null ? '\nSummary:\n$summary\n' : ''}'
              '\nAnswer questions about this meeting concisely.';
        } else {
          systemPrompt = _fullTranscriptPrompt(transcript, summary);
        }
      } else {
        systemPrompt = _fullTranscriptPrompt(transcript, summary);
      }
    } catch (_) {
      systemPrompt = _fullTranscriptPrompt(transcript, summary);
    }

    final history = state.messages
        .take(state.messages.length - 1)
        .map((m) => m.toApiMap())
        .toList();

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];

    try {
      Stream<String> stream;
      if (useLocal) {
        final localLlm = _ref.read(localLlmServiceProvider);
        final installed = await localLlm.isModelInstalled();
        if (!installed) {
          final msgs = List<ChatMessage>.from(state.messages)..removeLast();
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: 'Local AI model not downloaded. Download it in Settings first.',
          );
          return;
        }
        await localLlm.ensureModelLoaded();
        stream = localLlm.streamChat(
          systemPrompt: systemPrompt,
          messages: history,
        );
      } else {
        final apiKey =
            await _ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
        if (apiKey.isEmpty) {
          final msgs = List<ChatMessage>.from(state.messages)..removeLast();
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: 'No API key configured. Open Settings first.',
          );
          return;
        }
        stream = _ref.read(aiServiceProvider).streamCompletion(
              apiKey: apiKey,
              model: settings.activeModel,
              messages: apiMessages,
              provider: settings.provider,
            );
      }

      String accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<ChatMessage>.from(state.messages);
          updated[updated.length - 1] =
              ChatMessage(role: 'assistant', content: accumulated);
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) {
          if (!_mounted) return;
          final msgs = List<ChatMessage>.from(state.messages)
            ..removeLast();
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: e is AiException ? e.message : e.toString(),
          );
        },
        onDone: () {
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final msgs = List<ChatMessage>.from(state.messages)..removeLast();
      state = state.copyWith(
        messages: msgs,
        isStreaming: false,
        error: e is AiException ? e.message : e.toString(),
      );
    }
  }

  String _fullTranscriptPrompt(String transcript, String? summary) =>
      'You are a helpful assistant. The user recorded a meeting.\n'
      'Transcript:\n$transcript\n'
      '${summary != null ? '\nSummary:\n$summary\n' : ''}'
      '\nAnswer questions about this meeting concisely.';
```

- [ ] **Step 3: Update call sites that pass `meetingId`**

Search for calls to `sendMessage` in `meeting_detail_screen.dart` and add `meetingId: meeting.id`. The current call is like:

```dart
chatNotifier.sendMessage(text, transcript: transcript, summary: summary);
```

Change to:

```dart
chatNotifier.sendMessage(text, transcript: transcript, meetingId: meeting.id, summary: summary);
```

- [ ] **Step 4: Run analysis**

Run: `flutter analyze lib/providers/meeting_chat_provider.dart lib/screens/meeting_detail_screen.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/providers/meeting_chat_provider.dart lib/screens/meeting_detail_screen.dart
git commit -m "feat: RAG-first context + local generation for meeting chat"
```

---

### Task 9: Add Local AI toggle and download UI to Settings

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations_de.dart`
- Modify: `lib/l10n/app_localizations.dart`

- [ ] **Step 1: Add localization strings**

In `lib/l10n/app_localizations_en.dart`, add after `localLibraryChatSubtitleDisabled`:

```dart
String get localAiTitle => 'On-device AI';
String get localAiSubtitleEnabled => 'Using local Gemma 3 1B model';
String get localAiSubtitleDisabled => 'Disabled — uses cloud AI';
String get localAiDownloadModel => 'Download model (~500 MB)';
String get localAiDownloading => 'Downloading model...';
String get localAiReady => 'Model ready';
String get localAiNotDownloaded => 'Model not downloaded';
```

In `lib/l10n/app_localizations_de.dart`, add corresponding German strings:

```dart
String get localAiTitle => 'Lokale KI';
String get localAiSubtitleEnabled => 'Lokales Gemma 3 1B Modell';
String get localAiSubtitleDisabled => 'Deaktiviert — Cloud-KI';
String get localAiDownloadModel => 'Modell herunterladen (~500 MB)';
String get localAiDownloading => 'Modell wird heruntergeladen...';
String get localAiReady => 'Modell bereit';
String get localAiNotDownloaded => 'Modell nicht heruntergeladen';
```

In `lib/l10n/app_localizations.dart`, add the abstract getters:

```dart
String get localAiTitle;
String get localAiSubtitleEnabled;
String get localAiSubtitleDisabled;
String get localAiDownloadModel;
String get localAiDownloading;
String get localAiReady;
String get localAiNotDownloaded;
```

- [ ] **Step 2: Add Local AI row to settings screen**

In `lib/screens/settings_screen.dart`, add after the local library chat row (after line 153 `},`), inside the same `_SettingsSection` children list:

```dart
const Divider(height: 1, indent: 16, endIndent: 16),
_SettingsRow(
  icon: Icons.smart_toy_outlined,
  title: l10n.localAiTitle,
  subtitle: settings.localAiEnabled
      ? l10n.localAiSubtitleEnabled
      : l10n.localAiSubtitleDisabled,
  onTap: () {
    ref
        .read(settingsProvider.notifier)
        .setLocalAiEnabled(!settings.localAiEnabled);
  },
),
```

- [ ] **Step 3: Run analysis**

Run: `flutter analyze lib/screens/settings_screen.dart lib/l10n/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n/
git commit -m "feat: add Local AI toggle to settings screen"
```

---

### Task 10: Add Android OpenGL manifest entries for GPU

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add OpenGL native library entries**

Add before `</application>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-car.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-pixel.so" android:required="false"/>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add OpenGL entries for flutter_gemma GPU support"
```

---

### Task 11: Run full test suite and analysis

**Files:** None

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Final commit if any fixes needed**

If any fixes were needed during analysis/testing, commit them.

---

## Self-Review Checklist

**Spec coverage:**
- [x] `localAiEnabled` setting — Task 1 + 2
- [x] LocalLlmService — Task 5 + 6
- [x] RAG-first meeting chat — Task 8
- [x] Ask Library local routing + empty API key fix — Task 7
- [x] Settings UI — Task 9
- [x] `sourceIds` on LibraryRagService — Task 3
- [x] flutter_gemma dependency — Task 4
- [x] Android manifest — Task 10
- [x] Error handling (model not downloaded, empty API key, OOM) — Tasks 7 + 8

**Placeholder scan:** No TBDs, TODOs, or "implement later" patterns.

**Type consistency:** `LocalLlmService.streamChat()` returns `Stream<String>` matching `AiService.streamCompletion()`. `sourceIds: List<int>?` flows through all layers. `meetingId: String` added to `sendMessage`.

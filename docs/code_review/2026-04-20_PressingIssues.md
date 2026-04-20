# Code Review — 2026-04-20

## Summary

The codebase is well-structured with clean layering, good use of Riverpod, and solid separation of concerns. The main issues are concentrated in a few areas: a bloated `summary_sheet.dart` (1110 lines), missing `==`/`hashCode` on `Meeting`, duplicated code between `main.dart` intent handlers, and thin test coverage (2 test files).

### Stats

| Metric | Value |
|--------|-------|
| Dart files | 34 |
| Total lines (lib/) | ~4,500 |
| Test files | 2 |
| Generated files | 4 (`.g.dart`) |
| Analyzer issues | 45 (0 errors, 2 warnings, 43 info) |

---

## 1. General Project Health

**Good:**

- Clean layer-based architecture (models / providers / services / screens / widgets)
- Riverpod used consistently with code generation
- `analysis_options.yaml` has strict analyzer settings (`strict-casts`, `strict-inference`, `strict-raw-types`)
- Good use of `const` constructors on immutable model classes

**Issues:**

- `summary_sheet.dart` is 1110 lines — a single file containing the sheet state, body, 8+ sub-widgets, animations, input, and action bar. Should be split into at least 3–4 files.
- `voice_service.dart` at 707 lines mixes recording, FFmpeg preprocessing, silence detection, chunking, transcription (OpenAI + Gemini), and speaker relabeling. Should be split.
- No error reporting service (Sentry/Crashlytics) — `FlutterError.onError` and `PlatformDispatcher.instance.onError` are not overridden.

---

## 2. Dart Language

### Unused imports

- `lib/models/meeting.dart:1` — `dart:convert` imported but unused
- `lib/screens/settings_screen.dart:11` — `neumorphic_button.dart` imported but unused

### Missing `==`/`hashCode` on `Meeting`

`Meeting` is the core domain model used in Riverpod state but lacks `==`/`hashCode`. This means Riverpod's `NotifierProvider.family` will always consider meetings "changed" on every `copyWith`, causing unnecessary widget rebuilds. Given the review checklist's emphasis on immutability and value equality, this is a notable gap.

### String concatenation in loops

- `lib/providers/summary_provider.dart:132` — `state.summary + delta` in stream listener
- `lib/providers/meeting_provider.dart:180` — `summary += chunk` in `await for` loop
- `lib/providers/meeting_chat_provider.dart:88` — `accumulated += delta`

These are acceptable for small text streams but `StringBuffer` would be more idiomatic for longer transcripts.

### Curly braces

- `lib/providers/summary_provider.dart:368` — `if (_mounted)` without braces (lint warning)

### `debugPrint` in production

- `lib/services/voice_service.dart:29` — `TranscriptionLogger.log()` uses `debugPrint()` which is fine for debug output, but the logger should use `dart:developer` `log()` for production-grade logging.

### `catch` without `on` clause

- `lib/services/voice_service.dart:305`, `lib/services/voice_service.dart:314` — `catch (_) {}` silently swallowing errors in `_deleteFile`/`_deleteDirectory`

---

## 3. Widget Best Practices

### Widget decomposition

- `summary_sheet.dart` (1110 lines) — `_SheetBody` alone is ~250 lines of `build()`. Sub-widgets like `_ShimmerLoading`, `_ChatBubble`, `_ActionBar`, `_ActionButton`, `_FollowUpInput` are already extracted (good), but the file should be split across multiple files.
- `meeting_detail_screen.dart` (604 lines) — `_buildSummaryTab`, `_buildTranscriptTab`, `_buildChatTab` each return large widget trees. The chat tab especially should be extracted.

### `MediaQuery.of(context)` in build

- `summary_sheet.dart:670-685` — `_ShimmerLoading` calls `MediaQuery.of(context).size.width` 3 times in `build()`. Should use `MediaQuery.sizeOf(context)` or move width calculation to state.
- `summary_sheet.dart:757` — `_ChatBubble` calls `MediaQuery.of(context).size.width * 0.78` in build.
- `meeting_detail_screen.dart:381` — same pattern.

### Hardcoded colors

- `lib/screens/meeting_library_screen.dart:130-160` — Slidable actions use hardcoded `Colors.teal`, `Colors.blueGrey`, `Colors.amber.shade700`, `Colors.red` instead of `colorScheme`.
- `lib/screens/archived_meetings_screen.dart:59-79` — same issue.
- `lib/screens/summary_sheet.dart:1003` — `Colors.red.shade700` for recording indicator.
- `lib/screens/summary_sheet.dart:1024` — `Colors.red` for recording border.
- `lib/screens/summary_sheet.dart:1036` — `Colors.white` hardcoded for icon color.

### `const` usage

Multiple missing `const` constructors flagged by analyzer in `meeting_detail_screen.dart` (lines 203-207, 259-262, 318).

### Build method side effects

- `summary_sheet.dart:254-258` — `Future<void>.delayed(...).then(...)` called during `build()`. This is a side effect in the build method and will re-fire on every rebuild. Should be moved to a listener or `didUpdateWidget`.

---

## 4. State Management

### `SummaryState` — boolean flag soup

`SummaryState` uses multiple boolean flags (`isSpeaking`, `isCursorVisible`, `isFactChecking`) alongside `SummaryStatus` enum. The `status` enum already covers `idle/loading/streaming/done/error`, but `isFactChecking` is a cross-cutting concern that creates representable-but-confusing states (e.g., `status == error && isFactChecking == true`). A sealed class approach would be cleaner, though this is a moderate concern given the complexity tradeoff.

### `MeetingNotifier` — double-listening to libraries

`meeting_provider.dart:23-30` — `MeetingNotifier.build()` listens to both `meetingLibraryProvider` AND `archivedMeetingsProvider` to sync state. This means every library refresh triggers a state update for ALL open meeting detail screens. For a small app this is fine, but it doesn't scale.

### `MeetingNotifier` — placeholder pattern

`_placeholder()` returns a Meeting with empty title/audioPath. The `_isPlaceholder` guard prevents archive/unarchive on placeholders, but other methods like `transcribe()` and `summarize()` don't check for this, potentially operating on invalid data.

### `Summary` notifier — `_mounted` flag

`summary_provider.dart:32` — Manual `_mounted` boolean is used to guard state updates after dispose. This is a common pattern but Riverpod's `ref.onDispose` already handles cleanup. The `_mounted` flag is redundant if all async work is properly cancelled in `ref.onDispose`.

### `Summary` notifier — `TtsService` instantiated in notifier

`summary_provider.dart:29` — `final TtsService _tts = TtsService()` creates a new instance per notifier. This is correct since `Summary` is `keepAlive: true` (singleton), but TTS callbacks are set in `build()` which could be called multiple times if the provider is re-created.

### Cross-provider dependency — **DUPLICATE PROVIDER**

- `lib/providers/meeting_provider.dart:11-12` — `voiceServiceProvider` and `aiServiceProvider` are defined as plain `Provider()` at the top of this file, but `models_provider.dart:9` also defines `aiService` as a `@Riverpod` provider. **There are two `aiServiceProvider` definitions** — the one in `meeting_provider.dart` shadows the one in `models_provider.dart` depending on import order. This is a real bug waiting to happen.

---

## 5. Performance

### Unnecessary rebuilds

- `settings_screen.dart:128` — `ref.read(settingsProvider.notifier)` in `build()` — this doesn't cause rebuilds (it's `read` not `watch`), but it's unusual to see it in build. The notifier reference is stable, so this is harmless but confusing.
- `meeting_detail_screen.dart:60` — `ref.watch(meetingProvider(widget.meetingId).notifier)` — watching the notifier (not the state) is unnecessary. Should be `ref.read`.

### `ListView` without builder

Library screens use `ListView.builder` correctly. No issues here.

### Image optimization

No network images in the app. N/A.

---

## 6. Testing

**Very thin coverage.** Only 2 test files:

1. `import_service_test.dart` — 6 tests, well-written with fake repository
2. `meeting_chat_provider_test.dart` — 2 trivial tests (initial state + family isolation)

**Missing tests for:**

- `Summary` notifier (the most complex piece of state)
- `MeetingNotifier` (transcribe, summarize, retry, archive)
- `AiService` (streaming, error parsing, model filtering)
- `VoiceService` (audio processing, transcription)
- `Settings` notifier
- `MeetingRepository` (save/load/delete)
- `AppSettings` (fromJson/toJson roundtrip, activeModel resolution)
- `TtsService.stripMarkdown()` (static method, easy to unit test)

---

## 7. Accessibility

- No `Semantics` widgets used anywhere
- No `semanticLabel` on images/icons
- `_ActionButton` in `summary_sheet.dart:906` — tap target is a `Padding` + `Column`, may not meet 48x48 minimum
- `DocumentCarousel` chips may be too small for touch targets
- No `ExcludeSemantics` on decorative elements (drag handle, shimmer lines)

---

## 8. Security

**Good:**

- API keys stored in `flutter_secure_storage` with `encryptedSharedPreferences`
- Per-provider key separation

**Issues:**

- `AppSettings.toJson()` includes `openaiKey` and `openrouterKey` fields (lines 63-64). Even though keys are stored in secure storage, the `AppSettings` model carries them in memory and serializes them to JSON in SharedPreferences. If the JSON ever leaks, keys are exposed. The keys should NOT be part of the `AppSettings` model — they should be fetched from secure storage on demand only.

---

## 9. Platform-Specific

### Android

- Native code in `MainActivity.kt` is well-structured with compatibility shims for API 33+
- `RecordingService.kt` properly uses `FOREGROUND_SERVICE_TYPE_MICROPHONE`
- Intent filters cover all necessary cases

### iOS

- No iOS-specific code isolation. The app is Android-only currently (method channels, foreground services). If iOS support is planned, native code needs abstraction.

---

## 10. Dependencies

- `flutter_markdown` is **discontinued** — should migrate to `flutter_markdown_plus`
- Many packages have newer major versions available but are constrained by SDK/Flutter version bounds
- `ffmpeg_kit_flutter_new_min` — this package has known licensing issues (LGPL). Verify compliance.

---

## 11. Navigation

- Mix of `Navigator.push` (imperative) and `showModalBottomSheet` — consistent enough for the app's scope
- Route paths are not centralized as constants — magic strings like `'app.summsumm.OPEN_SETTINGS'` are used directly
- `_SummarySheetHost` pops the entire app on dismiss via `SystemNavigator.pop()` — correct for share-intent flow

---

## 12. Error Handling

**Good:**

- `AiException` with parsed error messages
- `VoiceTranscriptionException` with chunk index and log context
- Connectivity checks before transcription/summarization

**Issues:**

- `summary_provider.dart:254-258` — auto-dismiss on error after 3s with `Future.delayed` in `build()` — if the user navigates away and comes back, this fires again
- Raw exception strings shown to users in some SnackBar messages (e.g., `meeting_detail_screen.dart:58` — `Text('Error: $e')`)
- No global error handler — uncaught async errors will crash the app silently

---

## 13. Duplication

### Intent parsing duplicated

`main.dart` parses intent documents twice: once in `main()` (lines 39-75) and again in `_setupNewIntentHandler` (lines 194-230). The logic is nearly identical. Should be extracted to a shared function.

### Format helpers duplicated

`_formatDuration` and `_formatDateTime` are copy-pasted in:

- `meeting_library_screen.dart:212-222`
- `meeting_detail_screen.dart:455-465`
- `archived_meetings_screen.dart:131-140`

Should be in a shared utility file.

### Delete/rename dialogs duplicated

The delete confirmation dialog and rename dialog appear in:

- `meeting_library_screen.dart`
- `meeting_detail_screen.dart`
- `archived_meetings_screen.dart`

Should be extracted to a shared widget or helper function.

---

## 14. Priority Findings

| Priority | Issue | Location |
|----------|-------|----------|
| **High** | Two `aiServiceProvider` definitions — one shadows the other | `meeting_provider.dart:12` vs `models_provider.dart:9` |
| **High** | API keys serialized to SharedPreferences via `AppSettings.toJson()` | `app_settings.dart:56-65` |
| **High** | Side effect (`Future.delayed`) in `build()` method | `summary_sheet.dart:254-258` |
| **Medium** | `Meeting` missing `==`/`hashCode` — causes excessive rebuilds | `meeting.dart` |
| **Medium** | `flutter_markdown` discontinued | `pubspec.yaml` |
| **Medium** | No test coverage for core notifiers (`Summary`, `MeetingNotifier`) | `test/` |
| **Medium** | Hardcoded colors instead of theme | Multiple screens |
| **Low** | Duplicated intent parsing logic | `main.dart` |
| **Low** | Duplicated format helpers | 3 screens |
| **Low** | Unused imports | `meeting.dart`, `settings_screen.dart` |
| **Low** | Missing accessibility (Semantics, touch targets) | Multiple widgets |

---

## Recommended Fix Order

1. **Remove duplicate `aiServiceProvider`** from `meeting_provider.dart` — import from `models_provider.dart` instead
2. **Remove API keys from `AppSettings` model** — fetch from secure storage on demand only
3. **Move `Future.delayed` out of `build()`** in `summary_sheet.dart` — use `ref.listen` or `didUpdateWidget`
4. **Add `==`/`hashCode` to `Meeting`** — prevents unnecessary Riverpod rebuilds
5. **Migrate `flutter_markdown` → `flutter_markdown_plus`**
6. **Extract shared utilities** — format helpers, intent parsing, dialog helpers
7. **Add tests** — start with `Summary`, `MeetingNotifier`, `AiService`, and `stripMarkdown()`
8. **Replace hardcoded colors** with `Theme.of(context).colorScheme`
9. **Clean up unused imports** and analyzer warnings

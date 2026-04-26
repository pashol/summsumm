# Re-transcribe Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Re-transcribe action to the Transcript tab that clears the existing transcript, diarization, and summaries, resets the meeting to `recorded` status, and lets the user re-run transcription.

**Architecture:** A new `MeetingNotifier.resetTranscription()` method clears transcript fields via fixed `Meeting.copyWith` flags and persists. UI adds a conditional Re-transcribe button with a confirmation dialog in `_buildTranscriptTab`.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_gen (for localization)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/models/meeting.dart` | Add `clearRawTranscript`, `clearCleanedTranscript`, `clearSpeakerSegments` flags to `Meeting.copyWith`. |
| `lib/providers/meeting_provider.dart` | Add `resetTranscription()` method to `MeetingNotifier`. |
| `lib/l10n/app_en.arb` | Add English localization strings. |
| `lib/l10n/app_de.arb` | Add German localization strings. |
| `lib/l10n/app_localizations.dart` | Add getter declarations (auto-generated, but must be regenerated). |
| `lib/l10n/app_localizations_en.dart` | Add English getter implementations (auto-generated). |
| `lib/l10n/app_localizations_de.dart` | Add German getter implementations (auto-generated). |
| `lib/screens/meeting_detail_screen.dart` | Add Re-transcribe button, confirmation dialog, and conditional visibility logic. |
| `test/models/meeting_test.dart` | Test `Meeting.copyWith` clearing flags. |

---

### Task 1: Fix `Meeting.copyWith` — Allow Clearing Transcript Fields

`Meeting.copyWith` currently uses `rawTranscript: rawTranscript ?? this.rawTranscript`, so passing `null` never clears the field. We need explicit boolean flags.

**Files:**
- Modify: `lib/models/meeting.dart:118-164`

- [ ] **Step 1: Read the current `Meeting.copyWith` signature**

Read `lib/models/meeting.dart` lines 118-164 to confirm exact current code.

- [ ] **Step 2: Add clear flags to `Meeting.copyWith` signature**

Add three new parameters after `transcriptLog`:

```dart
  Meeting copyWith({
    String? id,
    DateTime? createdAt,
    int? durationSec,
    String? audioPath,
    String? title,
    String? transcript,
    String? rawTranscript,
    String? cleanedTranscript,
    bool? cleanupEnabled,
    MeetingStatus? status,
    String? lastError,
    bool clearLastError = false,
    String? provider,
    bool? archived,
    MeetingType? type,
    String? transcriptionLog,
    bool clearTranscriptionStatus = false,
    String? transcriptionStatus,
    bool clearTranscriptionProgress = false,
    double? transcriptionProgress,
    List<MeetingSummary>? summaries,
    List<SpeakerSegment>? speakerSegments,
    bool? wasLiveTranscribed,
    bool clearRawTranscript = false,
    bool clearCleanedTranscript = false,
    bool clearSpeakerSegments = false,
  }) {
```

- [ ] **Step 3: Update return body to use the flags**

Replace the three corresponding lines in the `Meeting(...)` constructor call:

```dart
      rawTranscript: clearRawTranscript
          ? null
          : (rawTranscript ?? this.rawTranscript),
      cleanedTranscript: clearCleanedTranscript
          ? null
          : (cleanedTranscript ?? this.cleanedTranscript),
      speakerSegments: clearSpeakerSegments
          ? null
          : (speakerSegments ?? this.speakerSegments),
```

- [ ] **Step 4: Run existing tests**

```bash
flutter test test/models/
```

Expected: All existing tests pass. No new tests yet.

- [ ] **Step 5: Commit**

```bash
git add lib/models/meeting.dart
git commit -m "fix(models): add clear flags to Meeting.copyWith for transcript fields"
```

---

### Task 2: Add `resetTranscription()` to `MeetingNotifier`

**Files:**
- Modify: `lib/providers/meeting_provider.dart`

- [ ] **Step 1: Read the current `MeetingNotifier` class**

Read `lib/providers/meeting_provider.dart` lines 1-509 to understand existing methods like `transcribe()`, `retry()`, and `_throttledSave()`.

- [ ] **Step 2: Add `resetTranscription()` method**

Insert the following method immediately after `retry()` (around line 478) or at the end of the class before the closing brace:

```dart
  Future<void> resetTranscription() async {
    final meeting = state;
    final repository = ref.read(meetingRepositoryProvider);

    state = meeting.copyWith(
      clearRawTranscript: true,
      clearCleanedTranscript: true,
      clearSpeakerSegments: true,
      summaries: [],
      status: MeetingStatus.recorded,
      clearLastError: true,
      clearTranscriptionStatus: true,
      clearTranscriptionProgress: true,
      provider: null,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
  }
```

- [ ] **Step 3: Run existing tests**

```bash
flutter test test/providers/
flutter analyze
```

Expected: No errors. Tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/meeting_provider.dart
git commit -m "feat(providers): add resetTranscription() to MeetingNotifier"
```

---

### Task 3: Add Localization Strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations_de.dart`

- [ ] **Step 1: Add English strings to `app_en.arb`**

Add these entries near the existing `retryButton` entries (around line 249):

```json
  "reTranscribeButton": "Re-transcribe",
  "@reTranscribeButton": {
    "description": "Button to redo transcription from scratch"
  },

  "reTranscribeConfirmTitle": "Replace transcript?",
  "@reTranscribeConfirmTitle": {
    "description": "Dialog title when confirming re-transcription"
  },

  "reTranscribeConfirmBody": "This will replace the existing transcript, diarization, and all summaries. This action cannot be undone.",
  "@reTranscribeConfirmBody": {
    "description": "Dialog body explaining destructive re-transcription"
  },
```

- [ ] **Step 2: Add German strings to `app_de.arb`**

Add the corresponding entries:

```json
  "reTranscribeButton": "Neu transkribieren",
  "@reTranscribeButton": {
    "description": "Button to redo transcription from scratch"
  },

  "reTranscribeConfirmTitle": "Transkript ersetzen?",
  "@reTranscribeConfirmTitle": {
    "description": "Dialog title when confirming re-transcription"
  },

  "reTranscribeConfirmBody": "Dadurch werden das vorhandene Transkript, die Diarisierung und alle Zusammenfassungen ersetzt. Diese Aktion kann nicht rückgängig gemacht werden.",
  "@reTranscribeConfirmBody": {
    "description": "Dialog body explaining destructive re-transcription"
  },
```

- [ ] **Step 3: Add getters to `app_localizations.dart`**

Add these declarations after `retryButton` (around line 381):

```dart
  /// Button to redo transcription from scratch
  ///
  /// In en, this message translates to:
  /// **'Re-transcribe'**
  String get reTranscribeButton;

  /// Dialog title when confirming re-transcription
  ///
  /// In en, this message translates to:
  /// **'Replace transcript?'**
  String get reTranscribeConfirmTitle;

  /// Dialog body explaining destructive re-transcription
  ///
  /// In en, this message translates to:
  /// **'This will replace the existing transcript, diarization, and all summaries. This action cannot be undone.'**
  String get reTranscribeConfirmBody;
```

- [ ] **Step 4: Add English implementations to `app_localizations_en.dart`**

Add these after `retryButton` (around line 161):

```dart
  @override
  String get reTranscribeButton => 'Re-transcribe';

  @override
  String get reTranscribeConfirmTitle => 'Replace transcript?';

  @override
  String get reTranscribeConfirmBody =>
      'This will replace the existing transcript, diarization, and all summaries. This action cannot be undone.';
```

- [ ] **Step 5: Add German implementations to `app_localizations_de.dart`**

Add these after the German `retryButton` (around line 162):

```dart
  @override
  String get reTranscribeButton => 'Neu transkribieren';

  @override
  String get reTranscribeConfirmTitle => 'Transkript ersetzen?';

  @override
  String get reTranscribeConfirmBody =>
      'Dadurch werden das vorhandene Transkript, die Diarisierung und alle Zusammenfassungen ersetzt. Diese Aktion kann nicht rückgängig gemacht werden.';
```

- [ ] **Step 6: Verify no missing imports and run flutter analyze**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_de.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_de.dart
git commit -m "feat(l10n): add re-transcribe button strings for en and de"
```

---

### Task 4: Add Re-transcribe Button and Confirmation Dialog to UI

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Read `_buildTranscriptTab` method**

Read `lib/screens/meeting_detail_screen.dart` lines 694-815 to understand the current transcript tab layout.

Key sections to note:
- Lines 752-802: `transcribed`, `summarizing`, `done` states show transcript content.
- Lines 803-813: `failed` state shows Retry button.

- [ ] **Step 2: Add confirmation dialog helper method**

Add the following private method to `_MeetingDetailScreenState` (anywhere among the other private methods like `_renameMeeting`):

```dart
  void _showReTranscribeConfirm(BuildContext ctx, MeetingNotifier provider) {
    final l10n = AppLocalizations.of(ctx)!;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.reTranscribeConfirmTitle),
        content: Text(l10n.reTranscribeConfirmBody),
        actions: _buildDialogActions(dialogCtx, [
          (
            label: l10n.cancelButton,
            onPressed: () => Navigator.pop(dialogCtx),
            isDefault: false,
          ),
          (
            label: l10n.reTranscribeButton,
            onPressed: () {
              Navigator.pop(dialogCtx);
              provider.resetTranscription();
            },
            isDefault: true,
          ),
        ]),
      ),
    );
  }
```

- [ ] **Step 3: Modify `_buildTranscriptTab` — extract re-transcribe visibility helper**

Add a helper getter or method to determine if the Re-transcribe button should be visible:

```dart
  bool _showReTranscribe(Meeting meeting) {
    if (meeting.type == MeetingType.document) return false;
    if (meeting.status == MeetingStatus.recorded) return false;
    if (meeting.status == MeetingStatus.transcribing) return false;
    // summarizing: shown but disabled (handled in UI)
    return true;
  }
```

- [ ] **Step 4: Modify `_buildTranscriptTab` — update transcribed/summarizing/done state branch**

The current code for `transcribed`/`summarizing`/`done` (lines 752-802) shows the transcript in an `Expanded` widget. We need to wrap it with a `Column` and add the action row above it.

Replace lines 752-802 with:

```dart
      case MeetingStatus.transcribed:
      case MeetingStatus.summarizing:
      case MeetingStatus.done:
        return Column(
          children: [
            if (meeting.type != MeetingType.document)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Row(
                  children: [
                    Tooltip(
                      message: _canDiarize(ref)
                          ? ''
                          : l10n.meetingDetailDiarizationRequires,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _diarize,
                            onChanged: _canDiarize(ref)
                                ? (v) => setState(() => _diarize = v)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.meetingDetailDiarizeSpeakers,
                            style: TextStyle(
                              color: _canDiarize(ref)
                                  ? null
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_showReTranscribe(meeting))
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.reTranscribeButton),
                        onPressed: meeting.status == MeetingStatus.summarizing
                            ? null
                            : () => _showReTranscribeConfirm(context, provider),
                      ),
                  ],
                ),
              ),
            if (meeting.type != MeetingType.document)
              const Divider(),
            if (meeting.type == MeetingType.document)
              MaterialBanner(
                content: Text(l10n.meetingDetailDocumentContent),
                actions: const [SizedBox.shrink()],
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            if (meeting.speakerSegments != null && meeting.speakerSegments!.isNotEmpty)
              Expanded(
                child: Scrollbar(
                  thumbVisibility: _isDesktop,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: meeting.speakerSegments!.length,
                    itemBuilder: (context, index) {
                      final segment = meeting.speakerSegments![index];
                      final startMin = (segment.startTime ~/ 60).toString().padLeft(2, '0');
                      final startSec = (segment.startTime % 60).toInt().toString().padLeft(2, '0');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '[$startMin:$startSec] ${segment.speakerLabel}: ${segment.text}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Expanded(
                child: Scrollbar(
                  thumbVisibility: _isDesktop,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                        data: meeting.transcript ?? '',
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                  ),
                ),
              ),
          ],
        );
```

- [ ] **Step 5: Add `_canDiarize` helper if not already present**

The refactored code uses `_canDiarize(ref)`. If this does not exist, add it:

```dart
  bool _canDiarize(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return settings.provider == 'openrouter' ||
        settings.transcriptionStrategy == TranscriptionStrategy.onDevice;
  }
```

If `_canDiarize` logic already exists inline, extract it to avoid duplication.

- [ ] **Step 6: Validate `failed` state branch still works**

Ensure the `failed` case (lines 803-813 in original) remains intact. In the `failed` state with a transcript present, `_showReTranscribe` returns `true`, so the button should appear. However, the current `failed` UI is a centered `Retry` button. We should update it to match the new layout.

Replace lines 803-813 with:

```dart
      case MeetingStatus.failed:
        if (meeting.type == MeetingType.document) return const SizedBox.shrink();
        return Column(
          children: [
            if (_showReTranscribe(meeting))
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.reTranscribeButton),
                      onPressed: () => _showReTranscribeConfirm(context, provider),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed: provider.retry,
                    child: Text(l10n.retryButton),
                  ),
                ),
              ),
            ),
          ],
        );
```

- [ ] **Step 7: Run flutter analyze and fix any issues**

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 8: Run app on emulator/device to verify UI**

```bash
flutter run
```

Manually verify:
1. Open a meeting with status `done` or `transcribed`.
2. Go to Transcript tab.
3. Re-transcribe button is visible next to diarization switch.
4. Tap it → confirmation dialog appears.
5. Confirm → status resets to `recorded`, transcript disappears, Transcribe button reappears.
6. Open a meeting with status `summarizing` → Re-transcribe button is visible but disabled.
7. Open a meeting with status `failed` (no transcript) → Re-transcribe is hidden, Retry button is shown.
8. Open a document-type meeting → Re-transcribe is never shown.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart
git commit -m "feat(ui): add re-transcribe button and confirmation dialog to transcript tab"
```

---

### Task 5: Add Unit Tests for `Meeting.copyWith` Clearing Flags

**Files:**
- Create: `test/models/meeting_test.dart` (if it doesn't exist)

- [ ] **Step 1: Read existing test structure**

```bash
ls test/models/
```

- [ ] **Step 2: Write test for clearing fields**

If `test/models/meeting_test.dart` does not exist, create it:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';

void main() {
  group('Meeting.copyWith clear flags', () {
    final meeting = Meeting(
      id: 'test-1',
      createdAt: DateTime(2024, 1, 1),
      durationSec: 60,
      audioPath: '/tmp/test.wav',
      title: 'Test Meeting',
      rawTranscript: 'raw text',
      cleanedTranscript: 'cleaned text',
      speakerSegments: const [],
      status: MeetingStatus.done,
      summaries: const [],
    );

    test('clearRawTranscript sets rawTranscript to null', () {
      final updated = meeting.copyWith(clearRawTranscript: true);
      expect(updated.rawTranscript, isNull);
      expect(updated.cleanedTranscript, 'cleaned text');
    });

    test('clearCleanedTranscript sets cleanedTranscript to null', () {
      final updated = meeting.copyWith(clearCleanedTranscript: true);
      expect(updated.cleanedTranscript, isNull);
      expect(updated.rawTranscript, 'raw text');
    });

    test('clearSpeakerSegments sets speakerSegments to null', () {
      final updated = meeting.copyWith(clearSpeakerSegments: true);
      expect(updated.speakerSegments, isNull);
    });

    test('multiple clear flags work together', () {
      final updated = meeting.copyWith(
        clearRawTranscript: true,
        clearCleanedTranscript: true,
        clearSpeakerSegments: true,
      );
      expect(updated.rawTranscript, isNull);
      expect(updated.cleanedTranscript, isNull);
      expect(updated.speakerSegments, isNull);
    });

    test('without clear flags, null values do not clear fields', () {
      final updated = meeting.copyWith(rawTranscript: null);
      expect(updated.rawTranscript, 'raw text');
    });
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/models/meeting_test.dart
```

Expected: All 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/models/meeting_test.dart
git commit -m "test(models): add tests for Meeting.copyWith clear flags"
```

---

## Self-Review

### Spec Coverage Check

| Spec Requirement | Plan Task |
|-----------------|-----------|
| Add Re-transcribe button | Task 4 |
| Show confirmation dialog | Task 4, Step 2 |
| Clear transcript + summaries | Task 2 (`resetTranscription`) |
| Reset status to `recorded` | Task 2 (`resetTranscription`) |
| Preserve metadata | Task 2 (fields omitted from `copyWith`) |
| Disable button during `summarizing` | Task 4, Step 4 (`onPressed: null` when summarizing) |
| Hide for documents | Task 4, Step 4 (`type != MeetingType.document`) |
| Localization strings (EN + DE) | Task 3 |
| Fix `Meeting.copyWith` null bug | Task 1 |
| Tests | Task 5 |

✅ All spec requirements covered.

### Placeholder Scan

- No "TBD", "TODO", "implement later" entries.
- All steps show exact code or exact commands.
- No vague references.

### Type Consistency

- `Meeting.copyWith` flags: `clearRawTranscript`, `clearCleanedTranscript`, `clearSpeakerSegments` used consistently.
- `MeetingNotifier.resetTranscription()` called via `provider.resetTranscription()` in UI.
- Localization keys: `reTranscribeButton`, `reTranscribeConfirmTitle`, `reTranscribeConfirmBody` match across all files.

✅ Consistent.

---

*Plan complete.*

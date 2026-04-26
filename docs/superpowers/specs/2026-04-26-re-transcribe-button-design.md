# Re-transcribe Button — Design Spec

**Date:** 2026-04-26  
**Topic:** Re-transcribe Button  
**Status:** Approved

---

## 1. Overview

Add a **Re-transcribe** action to the Transcript tab of the meeting detail screen. This allows users to discard an existing transcript (and all associated summaries/diarization) and start the transcription pipeline from scratch, with the ability to toggle diarization or switch strategy before re-running.

---

## 2. Motivation

Users currently have no way to re-run transcription on a meeting that already succeeded. Common scenarios:

- The first transcript was poor quality (noisy audio, wrong language model).
- The user forgot to enable speaker diarization and wants to retry with it on.
- The user switched from cloud to on-device transcription (or vice versa) and wants to re-process existing recordings.

The existing `Retry` button in the Summary tab only fires when `MeetingStatus.failed`. It also conflates transcription retry and summary retry. A dedicated, always-visible **Re-transcribe** action on the Transcript tab solves this cleanly.

---

## 3. Scope

### In Scope
- Add a **Re-transcribe** button to the Transcript tab.
- Show a destructive confirmation dialog.
- Clear all transcript data + summaries and reset status to `recorded`.
- Preserve meeting metadata (`audioPath`, `title`, `duration`, `wasLiveTranscribed`).
- Localization strings (EN + DE).

### Out of Scope
- Multiple transcript versions. The new transcript replaces the old one.
- Re-transcribe for `MeetingType.document`. Documents are imported files, not re-recordable audio.
- Auto-starting transcription after reset. User must manually press **Transcribe** so they can adjust settings first.

---

## 4. UI/UX

### 4.1 Transcript Tab States

| Status | Re-transcribe Button | Diarization Switch | Transcribe Button |
|--------|---------------------|-------------------|-------------------|
| `recorded` | Hidden | Visible, enabled | Visible, enabled (if audio exists) |
| `transcribing` | Hidden | Visible, disabled | Hidden |
| `transcribed` | **Visible** | Visible, enabled | Hidden |
| `summarizing` | **Disabled** | Visible, disabled | Hidden |
| `done` | **Visible** | Visible, enabled | Hidden |
| `failed` (no transcript) | Hidden | Visible, enabled | Hidden (Retry button shown instead) |
| `failed` (has transcript) | **Visible** | Visible, enabled | Hidden |

### 4.2 Confirmation Dialog

When the user taps **Re-transcribe**, display an `AlertDialog`:

- **Title:** "Replace transcript?" (`reTranscribeConfirmTitle`)
- **Body:** "This will replace the existing transcript, diarization, and all summaries. This action cannot be undone." (`reTranscribeConfirmBody`)
- **Actions:**
  - **Cancel** — dismiss dialog, no-op.
  - **Re-transcribe** — execute `resetTranscription()`, dismiss dialog.

### 4.3 Button Placement

In `_buildTranscriptTab`, when status is `transcribed`, `done`, or `failed` with an existing transcript, wrap the existing diarization switch + new button in a `Row` or `Column` at the top of the tab content, above the transcript scroll view.

```dart
// Pseudocode for top action row in transcribed/done/failed states
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        // Diarization switch (existing)
        Switch(...),
        Text(l10n.meetingDetailDiarizeSpeakers),
        const Spacer(),
        // NEW
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.reTranscribeButton),
          onPressed: () => _showReTranscribeConfirm(context, provider),
        ),
      ],
    ),
    const Divider(),
    // ... transcript content below
  ],
)
```

---

## 5. Data Model Changes

### 5.1 `Meeting.copyWith` Bug Fix

`Meeting.copyWith` currently uses `rawTranscript: rawTranscript ?? this.rawTranscript`, which means passing `rawTranscript: null` **does not clear** the field — it keeps the old value. The same applies to `cleanedTranscript` and `speakerSegments`.

**Fix:** Add `clearRawTranscript`, `clearCleanedTranscript`, `clearSpeakerSegments`, `clearProvider`, and `clearTranscriptionLog` boolean flags (default `false`) to `Meeting.copyWith`. When a flag is `true`, the corresponding field is explicitly set to `null` regardless of the passed value.

```dart
Meeting copyWith({
  // ... existing params ...
  bool clearRawTranscript = false,
  bool clearCleanedTranscript = false,
  bool clearSpeakerSegments = false,
  bool clearProvider = false,
  bool clearTranscriptionLog = false,
  // ...
}) {
  return Meeting(
    // ...
    rawTranscript: clearRawTranscript ? null : (rawTranscript ?? this.rawTranscript),
    cleanedTranscript: clearCleanedTranscript ? null : (cleanedTranscript ?? this.cleanedTranscript),
    speakerSegments: clearSpeakerSegments ? null : (speakerSegments ?? this.speakerSegments),
    provider: clearProvider ? null : (provider ?? this.provider),
    transcriptionLog: clearTranscriptionLog ? null : (transcriptionLog ?? this.transcriptionLog),
    // ...
  );
}
```

### 5.2 Fields Cleared on Re-transcribe

Fields cleared on re-transcribe:
- `rawTranscript` → `null`
- `cleanedTranscript` → `null`
- `speakerSegments` → `null`
- `summaries` → `[]`
- `status` → `MeetingStatus.recorded`
- `lastError` → `null` (via `clearLastError: true`)
- `transcriptionStatus` → `null` (via `clearTranscriptionStatus: true`)
- `transcriptionProgress` → `null` (via `clearTranscriptionProgress: true`)
- `provider` → `null`
- `transcriptionLog` → `null` (via `clearTranscriptionLog: true`)
- `wasLiveTranscribed` → `false`

Fields preserved:
- `id`, `createdAt`, `durationSec`, `audioPath`, `title`
- `type`, `archived`, `cleanupEnabled`

---

## 6. State Management

### 6.1 New `MeetingNotifier` Method

```dart
Future<void> resetTranscription() async {
  if (_isPlaceholder) return;

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
    clearProvider: true,
    clearTranscriptionLog: true,
    wasLiveTranscribed: false,
  );
  await repository.save(state);
  ref.read(meetingLibraryProvider.notifier).refresh();
  ref.read(archivedMeetingsProvider.notifier).refresh();
}
```

### 6.2 Update `retry()` Logic

The existing `retry()` method remains unchanged for backward compatibility. It handles the `failed` case where `transcript == null` (retry transcription) or `summaries.isEmpty` (retry summary). The new `resetTranscription()` is a separate, explicit user action.

---

## 7. Edge Cases

| Scenario | Behavior |
|----------|----------|
| Re-transcribe during `summarizing` | Button is disabled. Prevents race condition between summary generation and transcript wipe. |
| Re-transcribe with missing audio | After reset, status is `recorded`. The existing `_audioFileExists` check disables the Transcribe button and shows "Audio missing" label. |
| On-device model not yet downloaded | After reset + manual Transcribe, follows existing flow: initialize service → download model → transcribe. |
| Live-transcribed meeting (`wasLiveTranscribed == true`) | Flag is reset to `false`. On-device re-transcription will run full ASR from scratch, not skip it. |
| Document-type meetings | Re-transcribe is not shown. `_buildTranscriptTab` returns document-specific UI. |

---

## 8. Localization

### New Keys

| Key | English | German |
|-----|---------|--------|
| `reTranscribeButton` | "Re-transcribe" | "Neu transkribieren" |
| `reTranscribeConfirmTitle` | "Replace transcript?" | "Transkript ersetzen?" |
| `reTranscribeConfirmBody` | "This will replace the existing transcript, diarization, and all summaries. This action cannot be undone." | "Dadurch werden das vorhandene Transkript, die Diarisierung und alle Zusammenfassungen ersetzt. Diese Aktion kann nicht rückgängig gemacht werden." |

### Files to Update
- `lib/l10n/app_localizations.dart` — add getters
- `lib/l10n/app_localizations_en.dart` — add English strings
- `lib/l10n/app_localizations_de.dart` — add German strings

---

## 9. Testing Strategy

### Unit Tests (in `test/`)
- `MeetingNotifier.resetTranscription()` clears all transcript fields, sets status to `recorded`, and persists the meeting.
- `Meeting.copyWith(clearRawTranscript: true)` sets `rawTranscript` to `null` even when field previously had a value.
- `Meeting.copyWith(clearCleanedTranscript: true)` sets `cleanedTranscript` to `null`.
- `Meeting.copyWith(clearSpeakerSegments: true)` sets `speakerSegments` to `null`.

### Widget Tests (in `test/screens/`)
- Re-transcribe button is **visible** in Transcript tab when status is `transcribed`.
- Re-transcribe button is **disabled** when status is `summarizing`.
- Re-transcribe button is **hidden** in Transcript tab when status is `recorded`.
- Tapping Re-transcribe shows confirmation dialog.
- Confirming dialog triggers `resetTranscription()` and UI updates to `recorded` state.

---

## 10. Files to Modify

1. `lib/models/meeting.dart` — add `clearRawTranscript`, `clearCleanedTranscript`, `clearSpeakerSegments`, `clearProvider`, `clearTranscriptionLog` flags to `Meeting.copyWith`.
2. `lib/providers/meeting_provider.dart` — add `resetTranscription()` method.
3. `lib/screens/meeting_detail_screen.dart` — add Re-transcribe button + confirmation dialog.
4. `lib/l10n/app_localizations.dart` — add new string getters.
5. `lib/l10n/app_localizations_en.dart` — add English strings.
6. `lib/l10n/app_localizations_de.dart` — add German strings.

---

## 11. Rollout & Backward Compatibility

- No database migration needed. `Meeting.fromJson` handles missing fields gracefully.
- Existing `retry()` behavior is unchanged.
- The feature is purely additive (new UI action + new notifier method).

---

*End of spec.*

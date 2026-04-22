# Transcript Cleanup Feature Design

**Date:** 2026-04-23
**Status:** Draft

## Overview

Add automatic transcript cleanup for cloud transcription (OpenAI and OpenRouter). After raw transcription completes, send the transcript through the user's selected AI model to remove filler words, fix grammar, and smooth disfluencies. The cleaned version is displayed by default; the raw version is preserved for a future retry/custom-prompt feature.

## Goals

- Improve transcript readability for presentation
- Remove filler words (um, uh, like, you know, etc.)
- Fix false starts, repetitions, and grammar errors
- Preserve speaker labels and timestamps for diarized transcripts
- Maintain backward compatibility with existing meetings
- Store raw transcript for future retry with custom prompts

## Non-Goals

- UI toggle to switch between raw/cleaned (deferred to future retry feature)
- Cleanup for on-device transcription (out of scope)
- Manual editing of transcripts (out of scope)

## Architecture

### Data Model Changes

Add to `Meeting` model:
- `rawTranscript: String?` — the original transcription output
- `cleanedTranscript: String?` — the cleaned version
- `cleanupEnabled: bool` — whether cleanup is enabled (default: true for new cloud transcripts)

The existing `transcript` field becomes a computed getter:
```dart
String? get transcript => cleanedTranscript ?? rawTranscript;
```

This ensures backward compatibility — existing meetings with only `transcript` continue to work.

### Cleanup Service

New method in `AiService`:
```dart
Stream<String> cleanupTranscript({
  required String rawTranscript,
  required String provider,
  required String apiKey,
  required String model,
  bool diarized = false,
})
```

Uses the user's selected model (`settings.activeModel`) for cleanup.

### Prompt

```
Clean and refine the following transcript according to these rules:

- Keep timestamps and speaker labels exactly as they are (format: [hh:mm:ss] Speaker X:).
- Remove filler words, repetitions, false starts, and spoken-language artifacts.
- Rewrite all statements in correct written language (keep the original language).
- Correct grammar, sentence structure, and wording without changing the meaning.
- Ensure each sentence is clear, complete, and logically structured.
- Do not summarize or omit any content.
- Do not add new information or interpretations.
- Preserve the original order of statements strictly.
- Keep the wording precise and concise without embellishment.

Optional:
If a sentence is unclear, rewrite it as close as possible to the intended meaning without guessing.

Transcript:
[rawTranscript]
```

### Integration Flow

1. **Transcription completes** (`meeting_provider.dart`):
   - Save raw transcript to `rawTranscript`
   - Set `cleanupEnabled = true` (for cloud transcripts)
   - If `cleanupEnabled`, trigger cleanup

2. **Cleanup runs**:
   - Call `AiService.cleanupTranscript()` with streaming
   - Show progress in meeting status
   - Save cleaned output to `cleanedTranscript`
   - Update meeting status to `transcribed`

3. **UI displays**:
   - Always shows `transcript` getter (cleaned if available, else raw)
   - No toggle visible in this iteration

### Settings

No new settings needed. Cleanup is automatic for cloud transcripts.

## Files to Modify

- `lib/models/meeting.dart` — add fields, update getter, JSON serialization
- `lib/services/ai_service.dart` — add `cleanupTranscript()` method
- `lib/providers/meeting_provider.dart` — trigger cleanup after transcription
- `lib/screens/meeting_detail_screen.dart` — ensure UI uses `transcript` getter

## Error Handling

- If cleanup fails, keep raw transcript and show error snackbar
- User can retry transcription to attempt cleanup again
- Failed cleanup does not block summary generation (uses raw transcript)

## Testing

- Unit test: `cleanupTranscript` with sample messy transcript
- Unit test: `Meeting` JSON round-trip with new fields
- Widget test: Meeting detail screen shows cleaned transcript

## Future Work

- Retry with custom prompt (uses `rawTranscript`)
- UI toggle to view raw vs cleaned
- Cleanup for on-device transcription

## Open Questions

None.

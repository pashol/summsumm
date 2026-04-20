# Meeting Summary: Style, Language & Redo — Design Spec

## Summary

Add multiple summaries per meeting with configurable style and language. Users can generate additional summaries (e.g. concise vs detailed, different languages) and browse them via horizontal chips. A "Redo Summary" flow replaces the current inability to regenerate summaries.

## 1. Data Model Changes

### Meeting model

Remove:
- `summary`: `String?` — replaced by `summaries` list

Add:
- `summaries`: `List<MeetingSummary>` — defaults to `[]`

`Meeting.status` transitions: `done` now means `summaries.isNotEmpty`. The `summarizing` state tracks the in-progress summary.

### New class: MeetingSummary

```dart
class MeetingSummary {
  final String id;        // UUID
  final SummaryStyle style;
  final String language;  // e.g. 'Same as input', 'English', 'German'
  final String content;   // markdown text
  final DateTime createdAt;
}
```

Persisted as a list in the meeting JSON. Each summary is independently stored — no summary is ever deleted.

### New enum: SummaryStyle

```dart
enum SummaryStyle {
  concise,    // 3-5 bullet points, key points only
  brief,      // Short paragraph, no bullets (documents only)
  detailed,   // Thorough narrative with headers
  structured; // Decisions / Action Items / Open Questions (meetings only)
}
```

Helper method `forType(MeetingType)` returns the filtered list:
- `MeetingType.meeting` → `[concise, detailed, structured]`
- `MeetingType.document` → `[concise, brief, detailed]`

### AppSettings

Add:
- `summaryStyle`: `String`, default `'structured'`

Change:
- `language` default from `'English'` to `'Same as input'` (existing users keep their stored value; this only affects new installs)

Add to `kSupportedLanguages`:
- `'Same as input'` as the first entry

## 2. Prompt Templates

Four system prompts, selected by style + meeting type:

| Style | Meetings | Documents | Format |
|-------|----------|-----------|--------|
| **Concise** | Yes | Yes | 3-5 bullet points, key points only |
| **Brief** | No | Yes | Short paragraph, no bullets or headers |
| **Detailed** | Yes | Yes | Thorough narrative with headers |
| **Structured** | Yes | No | Decisions / Action Items / Open Questions / Context |

### Concise prompt

> You are an expert summarizer. Produce a brief summary with 3-5 bullet points covering only the key points. Do not elaborate. Do not wrap output in a code block.

### Brief prompt (documents only)

> You are an expert document summarizer. Write a short paragraph summarizing the key points of this document. Do not use bullet points or headers. Do not wrap output in a code block.

### Detailed prompt

> You are an expert summarizer. Produce a comprehensive summary with thorough coverage of each topic. Include context and reasoning. Use ## headers for topics, paragraphs for detail. Do not wrap output in a code block.

### Structured prompt (meetings only, same as current)

> You are an expert meeting summarizer. Extract: 1. Key decisions made 2. Action items with owners 3. Open questions 4. Important context. Use markdown headers and bullet points. Do not wrap output in a code block. Be concise and factual.

### Language suffix

Appended to all prompts when language != "Same as input":

> \n\nIMPORTANT: The summary must be in {language}.

## 3. UI & Interaction

### Summary tab states

| State | What's shown |
|-------|-------------|
| `recorded` (document) | "Summarize" button only (no dropdowns) |
| `recorded` (meeting) | "No transcript yet" message (unchanged) |
| `transcribing` | Spinner (unchanged) |
| `transcribed` | "Summarize" button only (no dropdowns) |
| `summarizing` | Chip row (all existing + new summary's chip auto-selected with spinner), streaming markdown for the new summary |
| `done` | **Chip row** at top, selected summary's markdown below |
| `failed` | Chip row (if other summaries exist) + error + "Retry" |

### Chip row

Horizontal scrolling row of `ChoiceChip` widgets:
- Each chip shows the style name only: "Concise", "Detailed", "Structured", "Brief"
- Duplicate styles are numbered: "Concise", "Concise 2", "Concise 3"
- Tapping a chip selects it and displays that summary's content below
- Selected chip is highlighted
- "+" chip at the end opens the style/language controls for adding a new summary

### Add new summary flow

1. User taps "+" chip
2. Inline controls appear: style dropdown (filtered by meeting type) + language dropdown + "Summarize" button
3. Dropdowns default to global settings values
4. User taps "Summarize" → confirmation dialog: "Generate a new summary in {language} with {style} style?"
5. On confirm: new `MeetingSummary` is created (empty content), added to list, streaming begins, new chip auto-selected
6. On completion, summary content is populated

### Initial summary flow (no summaries exist yet)

Same as current: "Summarize" button using global defaults. After generation completes, a single chip appears (e.g. "Structured"). No controls shown upfront.

### Settings screen

Add "Summary style" dropdown in the Summary section, alongside the existing language dropdown. The dropdown shows all 4 styles (no filtering in settings — filtering only happens in the meeting detail UI based on meeting type).

## 4. State & Logic

### MeetingNotifier

- `summarize({SummaryStyle? style, String? language})` — if no style/language passed, use global defaults. Resolves prompt template based on style + meeting type. Appends language suffix. Creates a new `MeetingSummary`, adds to `meeting.summaries`, sets status to `summarizing`, begins streaming.
- `retry()` — when status is `failed` and summaries is empty, behaves as before. When status is `failed` and summaries exist, retries the last in-progress summary.
- Streaming: each chunk appends to the last summary in the list. On completion, sets status to `done`.

### MeetingRepository

- Update `toJson()` / `fromJson()` to persist `summaries` list as a JSON array of `MeetingSummary` objects.
- Backward compatibility: if `summary` field exists (old format) but `summaries` is empty, migrate by creating a `MeetingSummary` with style `structured`, language `'Same as input'`, and the existing content.

### SettingsProvider

- Add `setSummaryStyle(String style)` method, persist to SharedPreferences.

### Meeting.status determination

- `done` = `summaries.isNotEmpty` and not currently summarizing
- `summarizing` = streaming in progress
- `transcribed` = transcript exists and `summaries.isEmpty`

### Language suffix helper

Move `_langSuffix` from `summary_provider.dart` to a shared location (e.g. `AppSettings` or a utility) so both `SummaryProvider` and `MeetingNotifier` can use it.

## 5. Backward Compatibility

- Old meetings with `summary` field but no `summaries` are migrated on load: a single `MeetingSummary` is created from the existing content with `style: structured`, `language: 'Same as input'`.
- The `summary` getter on `Meeting` can be kept as a convenience that returns the first (or selected) summary's content, to minimize refactoring of code that reads `meeting.summary`.

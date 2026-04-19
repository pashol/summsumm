# Meeting Detail Tabs Design

**Date:** 2026-04-19  
**Feature:** Replace the single-scroll meeting detail view with a Summary / Transcript / Chat tab switcher.

---

## Overview

The `MeetingDetailScreen` currently shows metadata, transcript, summary, and action buttons in a single scrollable column. This redesign replaces the body with a `TabBar` + `TabBarView` (3 tabs), keeping metadata pinned above the tabs.

---

## Screen Structure

```
AppBar (title, share / rename / delete actions)
────────────────────────────────────────────────
Metadata strip  (date, duration, provider, error banner)
────────────────────────────────────────────────
TabBar:  [ Summary | Transcript | Chat ]
────────────────────────────────────────────────
TabBarView  (fills remaining space; each tab independently scrollable)
```

The metadata strip is always visible regardless of the active tab. The error banner (currently in `_buildMetadata`) stays in the strip.

`_MeetingDetailScreenState` gains `TickerProviderStateMixin` and a `TabController(length: 3)`. No changes to providers or the `Meeting` model for the tab structure itself.

---

## Tab Content States

### Summary tab

| Meeting status | Displayed content |
|---|---|
| `recorded` | Placeholder: "No transcript yet — go to the Transcript tab to transcribe." |
| `transcribing` | Centered `CircularProgressIndicator` + "Transcribing…" label |
| `transcribed` | "Summarize" `ElevatedButton` (moves here from old `_buildActions`) |
| `summarizing` | Centered `CircularProgressIndicator` + "Summarizing…" label |
| `summarized` | Scrollable `MarkdownBody` of `meeting.summary` |
| `failed` (document) | Empty (`SizedBox.shrink`) |

### Transcript tab

| Meeting status | Displayed content |
|---|---|
| `recorded` | Diarize toggle + "Transcribe" `ElevatedButton` |
| `transcribing` | Centered `CircularProgressIndicator` + "Transcribing…" label |
| `transcribed` / `summarized` / `summarizing` | Scrollable plain text of `meeting.transcript` |
| `failed` (meeting type) | "Retry" `ElevatedButton` |
| `failed` (document type) | Empty |

### Chat tab

| Condition | Displayed content |
|---|---|
| No transcript (`meeting.transcript == null`) | Placeholder: "Transcribe the meeting first to start chatting." |
| Has transcript | Full chat UI (see below) |

---

## Chat Implementation

### Provider

New `meetingChatProvider` — a `StateNotifier` family keyed by `meetingId`:

```dart
final meetingChatProvider =
    StateNotifierProvider.family<MeetingChatNotifier, MeetingChatState, String>(
  (ref, meetingId) => MeetingChatNotifier(ref, meetingId),
);
```

`MeetingChatState` holds:
- `List<ChatMessage> messages` — conversation history
- `bool isStreaming` — true while AI response is in flight

Chat state is **ephemeral** — held in memory, cleared when the provider is disposed (i.e., when navigating away). No persistence to disk, no `Meeting` model changes.

### System prompt

```
You are a helpful assistant. The user recorded a meeting.
Transcript: <meeting.transcript>
Summary: <meeting.summary ?? '(not yet summarized)'>
Answer questions about this meeting concisely.
```

Uses `AiService.streamCompletion()` with the full `messages` list (system prompt as first message, conversation history appended). Streams response chunks into the last `ChatMessage`.

### Chat UI

Mirrors the summary sheet's chat layout:
- **Message list** — scrollable, auto-scrolls to bottom on new content; user bubbles right-aligned, assistant bubbles left-aligned.
- **Input row** — `TextField` + send `IconButton` pinned at the bottom of the tab.
- Send button disabled while `isStreaming == true` or transcript is absent.
- No voice input in this version.

---

## Files to touch

| File | Change |
|---|---|
| `lib/screens/meeting_detail_screen.dart` | Full redesign: add `TabController`, split body into 3 tab widgets |
| `lib/providers/meeting_chat_provider.dart` | New file: `MeetingChatNotifier` + `MeetingChatState` |

No changes to `Meeting` model, `MeetingNotifier`, `AiService`, or any `.g.dart` files.

---

## Out of scope

- Voice input in Chat tab
- Persisting chat history across navigation
- Tab deep-linking (always opens to Summary tab)

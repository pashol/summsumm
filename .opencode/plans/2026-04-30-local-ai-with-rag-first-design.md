# Local AI with RAG-First Generation

**Date:** 2026-04-30
**Status:** Approved

## Problem

Ask Library sends "missing authentication header" when no API key is configured because it falls back to an empty key and still calls the cloud API. Meeting chat always sends the full transcript in the system prompt, which is expensive for large meetings and exceeds the context window of small models.

## Solution

Add `flutter_gemma` (Gemma 3 1B, ~500MB) as an optional local generation backend. Introduce a "Local AI" setting (default: off). Make RAG retrieval the default context strategy for both Ask Library and meeting chat when the source is indexed.

## Architecture

```
User question
    |
Context assembly:
  Is meeting/source indexed in RAG?
    +-- Yes -> RAG search (filtered to source via sourceIds) -> context + citations
    +-- No  -> full transcript (meeting chat) / "no context" (Ask Library)
    |
Generation (based on localAiEnabled setting):
  +-- Cloud -> AiService.streamCompletion() (needs API key)
  +-- Local  -> LocalLlmService -> flutter_gemma Gemma 3 1B
```

## Components

### 1. Setting

`AppSettings.localAiEnabled`: `bool`, default `false`.

Requires:
- Add field to `AppSettings` model with `copyWith`, `toJson`, `fromJson`, `defaults`
- Add `setLocalAiEnabled(bool)` to `Settings` notifier
- Persist via `SharedPreferences`

### 2. LocalLlmService

New service in `lib/services/local_llm_service.dart`.

Responsibilities:
- `ensureModel()`: download Gemma 3 1B via `FlutterGemma.installModel()` if not present
- `streamChat({required String systemPrompt, required List<Map<String, dynamic>> messages})`: streaming generation via `InferenceModel.createChat()` + `generateChatResponseAsync()`
- `isModelReady`: check if model is downloaded and initialized
- `close()`: cleanup model instance
- Exposed as Riverpod provider (`@Riverpod(keepAlive: true)`)

Model details:
- Model: Gemma 3 1B (`ModelType.gemmaIt`)
- Format: `.task` file (MediaPipe, works on Android + iOS)
- Size: ~500MB
- Download URL: HuggingFace `litert-community/Gemma3-1B-IT`
- GPU preferred when available, CPU fallback

Lifecycle:
- Lazy init on first `streamChat()` call when `localAiEnabled` is true
- Model persists on device after download (no re-download)
- `close()` when setting toggled off or app dispose

### 3. RAG-First Context for Meeting Chat

Modify `MeetingChatNotifier.sendMessage()` in `lib/providers/meeting_chat_provider.dart`.

Current behavior:
```dart
final systemPrompt = '...Transcript:\n$transcript\n...';
```

New behavior:
```dart
// 1. Check if meeting is indexed in RAG
final metadata = await libraryRagMetadataStore.load();
final indexedSource = metadata.sourceForLibraryItem(meetingId);

if (indexedSource != null) {
  // 2. RAG search filtered to this meeting's source
  final searchResult = await libraryRagService.search(
    question,
    sourceIds: [indexedSource.ragSourceId],
  );
  // 3. Build prompt from retrieved context
  systemPrompt = '...Context:\n${searchResult.contextText}\n...';
} else {
  // Fallback: full transcript (current behavior)
  systemPrompt = '...Transcript:\n$transcript\n...';
}
```

Applies to both cloud and local generation. Saves tokens/cost on cloud, fits context window on local.

Requires:
- Inject `LibraryRagService` and `LibraryRagMetadataStore` into `MeetingChatNotifier`
- Add `sourceIds` parameter to `LibraryRagClient.search()`, `LibraryRagService.search()`, `MobileLibraryRagClient.search()`, and `FakeLibraryRagClient.search()`
- Pass `sourceIds` through to `MobileRag.instance.searchHybridWithContext(sourceIds: ...)`

### 4. Ask Library Chat

Modify `AskLibraryChatNotifier.sendMessage()` in `lib/providers/ask_library_chat_provider.dart`.

- If `localAiEnabled` is true: route to `LocalLlmService.streamChat()` instead of `AiService.streamCompletion()`
- If false: current cloud path (API key -> `AiService.streamCompletion()`)
- RAG search unchanged (already uses `mobile_rag_engine`)
- Error if local enabled but model not downloaded: show "Download model first" in chat error state

Also fix the original bug: when cloud mode and API key is empty, stop before calling `AiService` and show "No API key configured" error (matching summary sheet behavior).

### 5. Settings UI

New "Local AI" section in main settings screen (under API connection section).

Contains:
- Switch toggle: "Use on-device AI" (bound to `localAiEnabled`)
- Download button with progress indicator when model not yet downloaded
- Model size label: "~500 MB"
- Status: "Not downloaded" / "Ready" / "Downloading... X%"

### 6. LibraryRagService Changes

Add `sourceIds` parameter to `search()`:

```dart
Future<LibraryRagSearchResult> search(
  String query, {
  List<int>? sourceIds,
}) async {
  await initialize();
  return _client.search(query, sourceIds: sourceIds);
}
```

Propagate through `LibraryRagClient`, `MobileLibraryRagClient`, and `FakeLibraryRagClient`.

## What Stays Unchanged

- `mobile_rag_engine`: all indexing, search, chunking, citations, document parsing
- Cloud AI for summaries, follow-ups, voice transcription
- RAG index setup flow (enable, estimate, index, stale/ready states)
- `LibraryRagRepository` (no changes to sync/inspect/index logic)

## Error Handling

| Scenario | Behavior |
|---|---|
| Local enabled, model not downloaded | Show download prompt in chat, block send |
| Model OOM or init failure | Error in chat state, suggest switching to cloud |
| Cloud mode, empty API key | "No API key configured" error (fixes original bug) |
| RAG not indexed for meeting | Fall back to full transcript in prompt |
| RAG search returns empty context | "Could not find relevant context" message (Ask Library) or fall back to transcript (meeting chat) |

## Dependencies

- `flutter_gemma: ^0.14.0` added to `pubspec.yaml`
- Android: OpenGL manifest entries for GPU (optional, already may exist)
- iOS: minimum 16.0 in Podfile (required by MediaPipe)
- ProGuard rules for MediaPipe (already have rules for FFmpeg)

## Testing

- Unit tests for `LocalLlmService` with mock `FlutterGemma`
- Unit tests for RAG-first context assembly in `MeetingChatNotifier`
- Unit tests for generation routing (cloud vs local) in both chat providers
- Unit tests for `AppSettings.localAiEnabled` serialization
- Widget tests for settings UI toggle and download button
- Existing tests for Ask Library and meeting chat still pass

## Risks

- **Model quality**: Gemma 3 1B is small; RAG retrieval quality compensates but answers may be less nuanced than cloud
- **First-download UX**: 500MB download requires good progress UI and handling interruptions
- **Memory**: Model uses ~1-2GB RAM during inference; may struggle on low-end devices
- **flutter_gemma maturity**: v0.14.0, actively maintained (326 likes), but newer package than mobile_rag_engine

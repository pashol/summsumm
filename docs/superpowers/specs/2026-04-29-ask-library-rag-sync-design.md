# Ask Library RAG Sync Design

**Date:** 2026-04-29
**Status:** Approved design

## Goal

Update Ask Library so its local RAG index can detect library changes and incrementally sync only new, changed, or removed sources while keeping stale chat usable behind a clear warning.

## Context

Ask Library currently indexes the active library through `LibraryRagRepository.indexAll()` and stores app-to-RAG source metadata in `LibraryRagMetadataStore`. Chat retrieves local context through `LibraryRagService.search()` and sends only retrieved snippets plus the user's question to the selected AI provider.

The current implementation has two gaps:

- The index is not automatically classified as ready or stale after library content changes.
- Re-indexing does not remove old RAG sources before adding replacements, so repeated indexing can leave duplicate or outdated sources in the local RAG database.

## Chosen Approach

Use a manual stale prompt with incremental sync.

When Ask Library opens, inspect the current active library against saved RAG metadata. If the index is stale, keep chat available using the last built index and show a banner with an **Update index** action. When the user taps the action, update only changed parts of the index.

This approach avoids surprise CPU and battery use, preserves chat availability, and prevents old RAG sources from accumulating.

## Architecture

Keep sync logic in `LibraryRagRepository`, because it already owns text extraction, content hashing, metadata persistence, and calls into `LibraryRagService`.

Add a repository-level inspection operation:

```dart
Future<LibraryIndexInspection> inspectIndex(List<Meeting> meetings)
```

This compares current eligible library content with saved metadata and reports whether the index is not indexed, ready, or stale.

Add a repository-level sync operation:

```dart
Future<LibraryRagMetadata> syncLibrary(
  List<Meeting> meetings, {
  void Function(LibraryIndexProgress progress)? onProgress,
})
```

This updates the local RAG index incrementally:

- New eligible item: add it to RAG and save metadata.
- Changed eligible item: remove the old RAG source, add the new source, and save new metadata.
- Removed or archived item: remove the old RAG source and remove its metadata.
- Unchanged item: keep the existing RAG source and metadata.

`LibraryRagSetupNotifier` coordinates the UI-facing state:

- On Ask Library setup load, read `meetingLibraryProvider.future` and call `inspectIndex()`.
- Set readiness to `enabledNotIndexed`, `ready`, or `stale` based on inspection.
- On **Update index**, call `syncLibrary()` and expose progress.
- On successful sync, set readiness to `ready`.
- On sync failure, preserve `stale` when an old index exists so chat remains usable.

## Data Flow

Opening Ask Library:

```text
AskLibraryScreen
  -> libraryRagSetupProvider
  -> meetingLibraryProvider.future
  -> LibraryRagRepository.inspectIndex()
  -> readiness: enabledNotIndexed | ready | stale
```

Updating the index:

```text
AskLibraryScreen
  -> libraryRagSetupProvider.notifier.updateIndex()
  -> meetingLibraryProvider.future
  -> LibraryRagRepository.syncLibrary()
  -> LibraryRagService.removeSource()/addSource()
  -> LibraryRagMetadataStore.save()
  -> readiness: ready
```

Asking while stale:

```text
AskLibraryChatNotifier
  -> LibraryRagRepository.search(question)
  -> existing local RAG index
  -> AiService.streamCompletion(context + question)
```

The stale banner remains visible so users understand answers may miss recent changes.

## Stale Detection Rules

The index is stale when any of these conditions are true:

- A current eligible library item has no saved metadata entry.
- A current eligible library item's content hash differs from saved `contentHash`.
- Saved metadata contains a source whose library item is no longer active.

The index is not indexed when local library chat is enabled but no RAG metadata exists yet. If there is eligible content, the UI should show the existing estimate/start-indexing flow rather than the stale banner.

The index is ready when every eligible active source has matching metadata and no metadata points to removed or archived active-library items.

Title-only changes should update metadata for citation display without re-embedding the source text. If the content hash is unchanged and only the title differs, sync should preserve the existing `ragSourceId` and save refreshed metadata.

## UI Behavior

When readiness is `stale`, Ask Library should still show the chat UI. Add a banner above the message list or above the input:

```text
Library changed. Answers may miss recent updates.
```

The banner includes an **Update index** action.

While sync is running:

- Show indexing progress using the existing `LibraryIndexProgress` model.
- Disable sending new Ask Library messages to avoid mixing chat interactions with index mutation.
- Preserve existing chat messages.

If sync fails:

- Keep stale chat usable if prior metadata still exists.
- Show the error inline.
- Keep the **Update index** action available for retry.

## Error Handling

Per-source sync failures should not abort the whole sync. The repository should continue processing remaining sources and report failed item counts through progress.

If `removeSource()` fails for a changed or deleted item, keep the existing metadata entry and report a failure. This avoids claiming the index is ready while an old source may still be searchable.

If `addSource()` fails for a new or changed item, do not write new metadata for that item. Existing metadata should be preserved for changed items only if the old source was not removed.

If metadata loading fails, `LibraryRagMetadataStore` already returns empty metadata. The inspection flow should treat that as not indexed when eligible content exists.

## Testing

Unit tests should cover `LibraryRagRepository` without initializing the native RAG engine by using `FakeLibraryRagClient` through `LibraryRagService`.

Required test cases:

- Inspection returns not indexed when metadata is empty and eligible content exists.
- Inspection returns ready when metadata hashes match current eligible content.
- Inspection returns stale when a new eligible item appears.
- Inspection returns stale when an indexed item's content hash changes.
- Inspection returns stale when metadata points to a removed or archived item.
- Sync adds new eligible items.
- Sync removes deleted or archived items through `removeSource()`.
- Sync replaces changed items by removing the old source before adding the new source.
- Sync preserves unchanged items without re-adding them.
- Sync refreshes title metadata without re-embedding unchanged content.
- Provider state transitions cover `ready`, `stale`, `indexing`, and failed sync with stale chat preserved.

Manual verification:

- Index a library with at least one transcript.
- Add a new meeting or document and reopen Ask Library.
- Confirm the stale banner appears and chat remains usable.
- Tap **Update index** and confirm the banner disappears after sync.
- Edit or re-transcribe a meeting and confirm the source is replaced.
- Archive or delete an indexed item and confirm it no longer appears as a citation after update.

## Out Of Scope

- Fully automatic background indexing after every library mutation.
- Full RAG database rebuild as the default update path.
- Snippet-level citation highlighting or scrolling.
- User-selectable source filters.
- Downloadable multilingual RAG models.

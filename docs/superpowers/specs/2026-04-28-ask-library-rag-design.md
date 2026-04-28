# Ask Library RAG — Design Specification

**Date**: 2026-04-28
**Status**: Draft — Awaiting Review

## 1. Goal

Add an opt-in `Ask Library` feature that lets users ask contextual questions across all eligible items in their summsumm library. The feature uses `mobile_rag_engine` for local semantic/keyword retrieval, then sends only the retrieved context snippets plus the user's question to the selected AI provider for answer generation.

The first version prioritizes a reliable global chat experience over advanced filtering or multilingual model management.

## 2. Scope

V1 includes:

- A new `Ask Library` entry/screen from the library.
- Opt-in local library search/chat enablement.
- Bundled lightweight RAG model assets using `all-MiniLM-L6-v2` INT8 and its tokenizer.
- Explicit user confirmation before first indexing after seeing an estimate.
- Global search/chat over all indexed eligible library content.
- Source citations on answers.
- Citation navigation to the existing meeting/document detail screen.
- Meeting citations open the detail screen on the Transcript tab.

V1 indexes source content only:

- Meeting transcripts via `Meeting.transcript`.
- Imported document text from documents that can be extracted locally.

V1 excludes:

- AI summaries as retrieval sources.
- Snippet-level transcript scrolling/highlighting.
- User-selected source subsets and filters.
- Downloaded multilingual models.
- Package patching/forking for file-path model initialization.

Summaries and downloadable multilingual models are intentionally left as later options.

## 3. Package Constraint And Model Strategy

`mobile_rag_engine` 0.17.0 initializes from Flutter assets through `MobileRag.initialize(tokenizerAsset:, modelAsset:)`. It does not expose a public initialization path for already-downloaded model files.

To avoid patching or forking the package in V1, the app will bundle the lightweight model:

- `assets/rag/model.onnx`: `all-MiniLM-L6-v2` INT8, about 23 MB.
- `assets/rag/tokenizer.json`: matching HuggingFace tokenizer.

The feature remains opt-in, but activation controls indexing and use rather than model download. The setup UI must make this clear:

- Local library chat uses a small bundled English-first search model.
- Library content stays on device for indexing and retrieval.
- Only relevant retrieved snippets are sent to the selected AI provider when the user asks a question.
- Better multilingual search can be added later with downloadable models if the package supports file-path initialization or the app adopts a local compatibility layer.

## 4. User Flow

Initial state:

1. The library shows an `Ask Library` entry.
2. Opening it shows a setup state if local library chat is disabled or not indexed.
3. The setup state explains the bundled model, privacy boundary, and indexing behavior.

Enable and index:

1. User enables local library chat.
2. The app estimates indexing work from eligible library items.
3. The estimate shows item count, rough text size, likely chunk count, and a warning that first indexing can take time and battery.
4. User confirms indexing.
5. The app indexes eligible items and displays progress.
6. When indexing finishes, `Ask Library` becomes ready.

Chat:

1. User asks a question.
2. The app retrieves relevant local chunks across the library.
3. The app sends the retrieved context and question to the selected AI provider.
4. The streamed answer appears in chat.
5. Source citations appear below the answer.
6. Tapping a citation opens the cited meeting/document detail screen.

## 5. Architecture

The RAG feature should be isolated behind service and repository boundaries. UI code should not call `MobileRag` directly.

Components:

- `LibraryRagService`: thin wrapper around `mobile_rag_engine`; initializes `MobileRag`, indexes/removes sources, gets stats, performs hybrid search with context, and clears RAG data when needed.
- `LibraryRagRepository`: app-level source of truth for eligibility, indexing estimates, source metadata mapping, stale-index detection, and citation mapping.
- Riverpod providers: expose enablement, setup/readiness, indexing progress, failures, and chat state.
- `AskLibraryScreen`: chat and setup UI.
- Settings integration: local library chat toggle and model information.

This follows the app's existing layered structure:

- `lib/screens/` for UI.
- `lib/providers/` for Riverpod state.
- `lib/services/` for external package wrappers and app services.
- `lib/models/` for immutable data objects.

## 6. State Model

The feature should expose a small readiness state:

- `disabled`: local library chat is off; no indexing work should run.
- `enabledNotIndexed`: feature is on, but the user has not confirmed initial indexing.
- `indexing`: initial or refresh indexing is running.
- `ready`: global chat is available.
- `stale`: library content changed since the last index; chat still works, and the user can update the index.
- `failed`: setup, initialization, indexing, or search failed; UI shows retry where possible.

V1 should avoid automatic full-library indexing on every app launch. Index after explicit confirmation and refresh incrementally when content changes or when the user taps `Update index`.

## 7. Indexed Sources And Metadata

Eligible meeting source:

- `Meeting.type == MeetingType.meeting`.
- `Meeting.transcript` is non-null and non-empty.
- Metadata stores meeting id, title, content type `transcript`, created date, and source kind `meeting`.

Eligible document source:

- `Meeting.type == MeetingType.document`.
- The file exists at `Meeting.audioPath`.
- Local text extraction succeeds and yields non-empty text.
- Metadata stores meeting/document id, title, content type `document`, created date, and source kind `document`. Do not store the file path in RAG metadata; the app can resolve the local file path through the existing meeting repository when needed.

The repository must maintain a mapping between app library item ids and RAG source ids returned by `mobile_rag_engine`. This mapping is required for removals, refreshes, stale detection, and citation navigation.

The mapping should be persisted as a small JSON metadata file in the app documents directory for V1. It should include enough information to detect stale entries:

- Library item id.
- RAG source id.
- Indexed source kind.
- Indexed content hash or content length plus updated timestamp if available.
- Indexed title.
- Indexed at timestamp.

## 8. Retrieval And Prompting

Use hybrid retrieval with assembled context:

- Prefer `searchHybridWithContext()` over vector-only `search()`.
- Default to all indexed sources.
- Use an initial `topK` of `12` and `tokenBudget` of `3000` engine tokens, then tune after manual testing.
- Use `adjacentChunks: 1` to avoid isolated fragments.
- Use source metadata and returned chunks to build deterministic UI citations.

Prompt behavior:

- The system prompt tells the AI to answer only from the provided library context.
- If the retrieved context does not support an answer, the AI should say it could not find enough information.
- The prompt includes source labels to make inline references possible.
- The UI does not rely solely on the model for citations; it displays deterministic citation chips/cards from retrieved source metadata.

The chat request should use the existing `AiService.streamCompletion()` and selected `AppSettings.provider`/`AppSettings.activeModel` path.

## 9. Citations And Navigation

Each answer shows source citations below the streamed response.

Citation data:

- Source title.
- Source kind: `Meeting` or `Document`.
- Content type: `Transcript` or `Document`.
- App library item id.
- Optional short excerpt from the retrieved chunk.

Navigation behavior:

- Meeting transcript citations open `MeetingDetailScreen` for that meeting and switch to the Transcript tab.
- Document citations open the existing detail screen for that document item.
- V1 does not scroll to or highlight a matching snippet.

`MeetingDetailScreen` currently owns its tab controller internally. Implementation will need a minimal navigation parameter or route argument for the initial tab, defaulting to the current Summary tab behavior when omitted.

## 10. Indexing Estimate

Before first indexing, the app estimates and displays:

- Number of eligible meetings.
- Number of eligible documents.
- Approximate source text size.
- Approximate chunk count using the configured chunk target.
- A plain-language warning about time, battery, and storage.

The estimate does not need to predict exact runtime. It should be good enough for user consent.

## 11. Stale Index Handling

The repository marks the RAG index stale when:

- A meeting transcript changes.
- A document is imported, deleted, or renamed.
- A library item that was indexed is deleted.
- The user clears library data or RAG data.

When stale:

- `Ask Library` remains usable with the last built index.
- The UI shows an `Update index` action.
- Refresh indexing should update changed/new items and remove deleted sources when possible.

## 12. Error Handling

Initialization failure:

- Show setup error with retry.
- Keep chat disabled until initialization succeeds.

Indexing failure:

- Continue indexing other eligible items when a single item fails.
- Show counts for indexed and failed items.
- Allow retry.

No results:

- Show a normal assistant response explaining that no relevant library context was found.
- Do not send an empty-context hallucination-prone prompt as if context existed.

Search failure:

- Show inline error and preserve chat history.

AI streaming failure:

- Follow existing `AiException` handling style used by meeting/document chat.

Source navigation failure:

- If the cited item no longer exists, show a lightweight error and leave the user on `Ask Library`.

## 13. Testing

Unit tests should not initialize the native Rust/ONNX engine. `mobile_rag_engine` supports mock injection through `MobileRag.setMockInstance()`, and app code should also depend on service/repository abstractions to make tests straightforward.

Test coverage:

- Estimate generation includes eligible transcripts/documents and excludes empty/missing content.
- Indexing continues after per-item failures.
- Source metadata mapping is persisted and restored.
- Stale detection marks changed library content.
- Chat builds an AI prompt from retrieved context.
- No-results path avoids unsupported answers.
- Citation mapping opens the correct detail target.
- Provider state transitions cover `disabled`, `enabledNotIndexed`, `indexing`, `ready`, `stale`, and `failed`.

Integration/manual verification:

- Enable feature and confirm indexing on a library with at least one transcript and one PDF document.
- Ask a question whose answer exists in a transcript.
- Ask a question whose answer exists in a document.
- Tap both citation types.
- Delete or change a source and verify stale/update behavior.
- Run `flutter test` and `flutter analyze` after implementation.

## 14. Open Follow-Ups For Later

- Downloadable multilingual model support once file-path initialization is available or a compatibility layer is accepted.
- Re-indexing workflow for switching embedding models.
- Optional inclusion of AI summaries in the index.
- Filters by source type, date range, archived state, or selected meetings/documents.
- Snippet-level transcript navigation with scroll/highlight.
- Background indexing policy after the first explicit user-confirmed index.

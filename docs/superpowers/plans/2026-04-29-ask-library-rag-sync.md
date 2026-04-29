# Ask Library RAG Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add manual stale detection and incremental sync for Ask Library's local RAG index.

**Architecture:** Keep sync decisions in `LibraryRagRepository`, expose readiness and update actions through `LibraryRagSetupNotifier`, and keep `AskLibraryScreen` responsible only for rendering chat, stale warning, and indexing progress. The RAG engine remains behind `LibraryRagService`; app metadata remains persisted by `LibraryRagMetadataStore`.

**Tech Stack:** Flutter, Dart, Riverpod, `mobile_rag_engine`, existing `Meeting` model, existing RAG metadata JSON store, `flutter_test`.

---

## File Structure

- Modify: `lib/models/library_rag.dart` to add `LibraryIndexInspection` and `LibraryIndexInspectionStatus`.
- Modify: `lib/services/library_rag_service.dart` test fake to track add/remove calls and support deterministic source IDs.
- Modify: `lib/services/library_rag_repository.dart` to add `inspectIndex()` and `syncLibrary()`.
- Modify: `lib/providers/library_rag_provider.dart` to add inspection on setup load and update-index action.
- Modify: `lib/screens/ask_library_screen.dart` to show stale banner and route update action to the provider.
- Modify: `test/services/library_rag_repository_test.dart` to cover inspection and sync behavior.
- Verify: `test/providers/library_rag_provider_test.dart` remains passing after provider changes.

The worktree currently contains unrelated local modifications. Do not revert them. Stage only files changed for each task.

---

### Task 1: Add Inspection Model

**Files:**
- Modify: `lib/models/library_rag.dart`
- Test: `test/services/library_rag_repository_test.dart`

- [ ] **Step 1: Write a failing model usage test**

Add this test to `test/services/library_rag_repository_test.dart` inside `main()`:

```dart
  test('LibraryIndexInspection exposes status and counts', () {
    const inspection = LibraryIndexInspection(
      status: LibraryIndexInspectionStatus.stale,
      eligibleItems: 3,
      indexedItems: 2,
      staleItems: 1,
    );

    expect(inspection.status, LibraryIndexInspectionStatus.stale);
    expect(inspection.eligibleItems, 3);
    expect(inspection.indexedItems, 2);
    expect(inspection.staleItems, 1);
    expect(inspection.hasUsableIndex, isTrue);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/library_rag_repository_test.dart --plain-name "LibraryIndexInspection exposes status and counts"`

Expected: FAIL because `LibraryIndexInspection` and `LibraryIndexInspectionStatus` are not defined.

- [ ] **Step 3: Add inspection model types**

Modify `lib/models/library_rag.dart` after `LibraryIndexProgress`:

```dart
enum LibraryIndexInspectionStatus { notIndexed, ready, stale }

class LibraryIndexInspection {
  final LibraryIndexInspectionStatus status;
  final int eligibleItems;
  final int indexedItems;
  final int staleItems;

  const LibraryIndexInspection({
    required this.status,
    this.eligibleItems = 0,
    this.indexedItems = 0,
    this.staleItems = 0,
  });

  bool get hasUsableIndex => indexedItems > 0;
}
```

- [ ] **Step 4: Run the model test to verify it passes**

Run: `flutter test test/services/library_rag_repository_test.dart --plain-name "LibraryIndexInspection exposes status and counts"`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/models/library_rag.dart test/services/library_rag_repository_test.dart
git commit -m "feat(rag): add index inspection model"
```

Expected: commit succeeds. If unrelated edits exist in either file, use non-interactive path-specific staging only and do not revert unrelated changes.

---

### Task 2: Improve Fake RAG Client Observability

**Files:**
- Modify: `lib/services/library_rag_service.dart`
- Test: `test/services/library_rag_repository_test.dart`

- [ ] **Step 1: Write a failing fake-client behavior test**

Add this test to `test/services/library_rag_repository_test.dart` inside `main()`:

```dart
  test('fake rag client records added and removed sources', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 7;
    final service = LibraryRagService(client: client);

    final sourceId = await service.addSource(
      text: 'alpha beta gamma',
      title: 'Source title',
      metadataJson: '{"libraryItemId":"a"}',
    );
    await service.removeSource(sourceId);

    expect(sourceId, 7);
    expect(client.addedDocuments.single.text, 'alpha beta gamma');
    expect(client.addedDocuments.single.name, 'Source title');
    expect(client.removedSourceIds, [7]);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/library_rag_repository_test.dart --plain-name "fake rag client records added and removed sources"`

Expected: FAIL because `nextSourceId`, `addedDocuments`, and `removedSourceIds` do not exist.

- [ ] **Step 3: Add fake document record and tracking fields**

Modify `lib/services/library_rag_service.dart` before `FakeLibraryRagClient`:

```dart
class FakeLibraryRagDocument {
  final String text;
  final String name;
  final String metadata;
  final int sourceId;

  const FakeLibraryRagDocument({
    required this.text,
    required this.name,
    required this.metadata,
    required this.sourceId,
  });
}
```

Replace `FakeLibraryRagClient` with:

```dart
class FakeLibraryRagClient implements LibraryRagClient {
  int initializeCalls = 0;
  int nextSourceId = 99;
  String? lastText;
  String? lastName;
  String? lastMetadata;
  final List<FakeLibraryRagDocument> addedDocuments = [];
  final List<int> removedSourceIds = [];
  LibraryRagSearchResult searchResult = const LibraryRagSearchResult(
    contextText: '',
    chunks: [],
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<int> addDocument(
    String text, {
    required String name,
    required String metadata,
  }) async {
    lastText = text;
    lastName = name;
    lastMetadata = metadata;
    final sourceId = nextSourceId++;
    addedDocuments.add(FakeLibraryRagDocument(
      text: text,
      name: name,
      metadata: metadata,
      sourceId: sourceId,
    ));
    return sourceId;
  }

  @override
  Future<void> removeSource(int sourceId) async {
    removedSourceIds.add(sourceId);
  }

  @override
  Future<LibraryRagSearchResult> search(String query) async => searchResult;

  @override
  Future<void> clearAllData() async {}
}
```

- [ ] **Step 4: Run affected tests**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/services/library_rag_service.dart test/services/library_rag_repository_test.dart
git commit -m "test(rag): track fake rag source changes"
```

Expected: commit succeeds.

---

### Task 3: Implement Index Inspection

**Files:**
- Modify: `lib/services/library_rag_repository.dart`
- Test: `test/services/library_rag_repository_test.dart`

- [ ] **Step 1: Add inspection tests**

Add these tests to `test/services/library_rag_repository_test.dart` inside `main()`:

```dart
  test('inspectIndex returns notIndexed when metadata is empty and content exists', () async {
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: _MemoryMetadataStore(),
      documentTextExtractor: (_) async => '',
    );

    final inspection = await repository.inspectIndex([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    expect(inspection.status, LibraryIndexInspectionStatus.notIndexed);
    expect(inspection.eligibleItems, 1);
    expect(inspection.indexedItems, 0);
  });

  test('inspectIndex returns ready when metadata matches content hash', () async {
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.indexAll([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final inspection = await repository.inspectIndex([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    expect(inspection.status, LibraryIndexInspectionStatus.ready);
    expect(inspection.eligibleItems, 1);
    expect(inspection.indexedItems, 1);
    expect(inspection.staleItems, 0);
  });

  test('inspectIndex returns stale when a new eligible item appears', () async {
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.indexAll([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final inspection = await repository.inspectIndex([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
      _meeting(id: 'b', transcript: 'delta epsilon'),
    ]);

    expect(inspection.status, LibraryIndexInspectionStatus.stale);
    expect(inspection.eligibleItems, 2);
    expect(inspection.indexedItems, 1);
    expect(inspection.staleItems, 1);
  });

  test('inspectIndex returns stale when indexed content changes', () async {
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.indexAll([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final inspection = await repository.inspectIndex([
      _meeting(id: 'a', transcript: 'changed transcript'),
    ]);

    expect(inspection.status, LibraryIndexInspectionStatus.stale);
    expect(inspection.staleItems, 1);
  });

  test('inspectIndex returns stale when metadata points to removed item', () async {
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.indexAll([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final inspection = await repository.inspectIndex(const []);

    expect(inspection.status, LibraryIndexInspectionStatus.stale);
    expect(inspection.eligibleItems, 0);
    expect(inspection.indexedItems, 1);
    expect(inspection.staleItems, 1);
  });
```

- [ ] **Step 2: Run inspection tests to verify they fail**

Run: `flutter test test/services/library_rag_repository_test.dart --plain-name "inspectIndex"`

Expected: FAIL because `inspectIndex()` is not defined.

- [ ] **Step 3: Add inspection implementation**

Modify `lib/services/library_rag_repository.dart` by adding this method after `indexAll()`:

```dart
  Future<LibraryIndexInspection> inspectIndex(List<Meeting> meetings) async {
    final metadata = await _metadataStore.load();
    final candidates = await _eligibleCandidates(meetings);
    final activeIds = candidates.map((candidate) => candidate.meeting.id).toSet();
    final metadataByItem = {
      for (final source in metadata.sources) source.libraryItemId: source,
    };

    var indexedItems = 0;
    var staleItems = 0;

    for (final candidate in candidates) {
      final source = metadataByItem[candidate.meeting.id];
      if (source == null) {
        staleItems++;
        continue;
      }
      indexedItems++;
      if (source.contentHash != _hash(candidate.text)) {
        staleItems++;
      }
    }

    for (final source in metadata.sources) {
      if (!activeIds.contains(source.libraryItemId)) {
        staleItems++;
      }
    }

    final status = metadata.sources.isEmpty
        ? LibraryIndexInspectionStatus.notIndexed
        : staleItems == 0
            ? LibraryIndexInspectionStatus.ready
            : LibraryIndexInspectionStatus.stale;

    return LibraryIndexInspection(
      status: status,
      eligibleItems: candidates.length,
      indexedItems: indexedItems,
      staleItems: staleItems,
    );
  }
```

Add this helper near `_textFor()`:

```dart
  Future<List<_IndexCandidate>> _eligibleCandidates(List<Meeting> meetings) async {
    final eligible = <_IndexCandidate>[];
    for (final meeting in meetings) {
      final text = await _textFor(meeting);
      if (text.trim().isEmpty) continue;
      eligible.add(_IndexCandidate(meeting: meeting, text: text));
    }
    return eligible;
  }
```

- [ ] **Step 4: Refactor `indexAll()` to use `_eligibleCandidates()` without changing behavior**

In `lib/services/library_rag_repository.dart`, replace the first candidate-building loop in `indexAll()` with:

```dart
    final eligible = <_IndexCandidate>[];
    for (var i = 0; i < meetings.length; i++) {
      final meeting = meetings[i];
      onProgress?.call(LibraryIndexProgress(
        indexedItems: i,
        totalItems: meetings.length,
        failedItems: 0,
        currentTitle: meeting.title,
      ));
      final text = await _textFor(meeting);
      if (text.trim().isEmpty) continue;
      eligible.add(_IndexCandidate(meeting: meeting, text: text));
    }
```

This preserves the existing progress-before-document-extraction behavior. Do not replace it with `_eligibleCandidates()` because the current test expects progress to fire before slow document extraction.

- [ ] **Step 5: Run repository tests**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/services/library_rag_repository.dart test/services/library_rag_repository_test.dart
git commit -m "feat(rag): inspect ask library index freshness"
```

Expected: commit succeeds.

---

### Task 4: Implement Incremental Sync

**Files:**
- Modify: `lib/services/library_rag_repository.dart`
- Test: `test/services/library_rag_repository_test.dart`

- [ ] **Step 1: Add sync tests**

Add these tests to `test/services/library_rag_repository_test.dart` inside `main()`:

```dart
  test('syncLibrary adds new eligible items', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 10;
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );

    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final metadata = await store.load();
    expect(client.addedDocuments.length, 1);
    expect(client.removedSourceIds, isEmpty);
    expect(metadata.sources.single.libraryItemId, 'a');
    expect(metadata.sources.single.ragSourceId, 10);
  });

  test('syncLibrary preserves unchanged items without re-adding them', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 10;
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);
    client.addedDocuments.clear();

    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    final metadata = await store.load();
    expect(client.addedDocuments, isEmpty);
    expect(client.removedSourceIds, isEmpty);
    expect(metadata.sources.single.ragSourceId, 10);
  });

  test('syncLibrary replaces changed items by removing old source first', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 10;
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);
    client.addedDocuments.clear();

    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'changed transcript'),
    ]);

    final metadata = await store.load();
    expect(client.removedSourceIds, [10]);
    expect(client.addedDocuments.single.sourceId, 11);
    expect(metadata.sources.single.ragSourceId, 11);
  });

  test('syncLibrary removes deleted items', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 10;
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);

    await repository.syncLibrary(const []);

    final metadata = await store.load();
    expect(client.removedSourceIds, [10]);
    expect(metadata.sources, isEmpty);
  });

  test('syncLibrary refreshes title metadata without re-embedding', () async {
    final client = FakeLibraryRagClient()..nextSourceId = 10;
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );
    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
    ]);
    client.addedDocuments.clear();

    await repository.syncLibrary([
      _meeting(id: 'a', transcript: 'alpha beta gamma', title: 'Renamed meeting'),
    ]);

    final metadata = await store.load();
    expect(client.addedDocuments, isEmpty);
    expect(client.removedSourceIds, isEmpty);
    expect(metadata.sources.single.title, 'Renamed meeting');
    expect(metadata.sources.single.ragSourceId, 10);
  });
```

Update the `_meeting` helper signature in the same file to accept an optional title:

```dart
Meeting _meeting({
  required String id,
  required String transcript,
  String? title,
}) =>
    Meeting(
      id: id,
      createdAt: DateTime.utc(2026, 4, 28),
      durationSec: 60,
      audioPath: '/tmp/$id.m4a',
      title: title ?? 'Meeting $id',
      rawTranscript: transcript,
      status: MeetingStatus.transcribed,
    );
```

- [ ] **Step 2: Run sync tests to verify they fail**

Run: `flutter test test/services/library_rag_repository_test.dart --plain-name "syncLibrary"`

Expected: FAIL because `syncLibrary()` is not defined.

- [ ] **Step 3: Add metadata builder helper**

Modify `lib/services/library_rag_repository.dart` by adding these helpers before `_hash()`:

```dart
  IndexedLibrarySource _indexedSource({
    required Meeting meeting,
    required String text,
    required int ragSourceId,
  }) {
    final sourceKind = meeting.type == MeetingType.document
        ? LibrarySourceKind.document
        : LibrarySourceKind.meeting;
    final contentType = meeting.type == MeetingType.document
        ? LibraryContentType.document
        : LibraryContentType.transcript;
    return IndexedLibrarySource(
      libraryItemId: meeting.id,
      ragSourceId: ragSourceId,
      sourceKind: sourceKind,
      contentType: contentType,
      title: meeting.title,
      contentHash: _hash(text),
      contentLength: text.length,
      indexedAt: DateTime.now().toUtc(),
    );
  }

  String _metadataJson(Meeting meeting) {
    final sourceKind = meeting.type == MeetingType.document
        ? LibrarySourceKind.document
        : LibrarySourceKind.meeting;
    final contentType = meeting.type == MeetingType.document
        ? LibraryContentType.document
        : LibraryContentType.transcript;
    return jsonEncode({
      'libraryItemId': meeting.id,
      'sourceKind': sourceKind.name,
      'contentType': contentType.name,
      'title': meeting.title,
      'createdAt': meeting.createdAt.toUtc().toIso8601String(),
    });
  }
```

- [ ] **Step 4: Refactor `indexAll()` to use helpers**

In `lib/services/library_rag_repository.dart`, replace the per-candidate metadata block inside `indexAll()` with:

```dart
        final ragSourceId = await _ragService.addSource(
          text: candidate.text,
          title: candidate.meeting.title,
          metadataJson: _metadataJson(candidate.meeting),
        );
        indexed.add(_indexedSource(
          meeting: candidate.meeting,
          text: candidate.text,
          ragSourceId: ragSourceId,
        ));
```

Remove now-unused local variables `sourceKind`, `contentType`, and `sourceMetadata` from that block.

- [ ] **Step 5: Add `syncLibrary()` implementation**

Add this method after `inspectIndex()` in `lib/services/library_rag_repository.dart`:

```dart
  Future<LibraryRagMetadata> syncLibrary(
    List<Meeting> meetings, {
    void Function(LibraryIndexProgress progress)? onProgress,
  }) async {
    final previous = await _metadataStore.load();
    final previousByItem = {
      for (final source in previous.sources) source.libraryItemId: source,
    };
    final candidates = await _eligibleCandidates(meetings);
    final activeIds = candidates.map((candidate) => candidate.meeting.id).toSet();
    final nextSources = <IndexedLibrarySource>[];
    var failed = 0;
    var processed = 0;

    for (final source in previous.sources) {
      if (!activeIds.contains(source.libraryItemId)) {
        try {
          await _ragService.removeSource(source.ragSourceId);
        } catch (_) {
          failed++;
          nextSources.add(source);
        }
      }
    }

    for (final candidate in candidates) {
      onProgress?.call(LibraryIndexProgress(
        indexedItems: processed,
        totalItems: candidates.length,
        failedItems: failed,
        currentTitle: candidate.meeting.title,
      ));

      final previousSource = previousByItem[candidate.meeting.id];
      final nextHash = _hash(candidate.text);
      if (previousSource != null && previousSource.contentHash == nextHash) {
        nextSources.add(IndexedLibrarySource(
          libraryItemId: previousSource.libraryItemId,
          ragSourceId: previousSource.ragSourceId,
          sourceKind: previousSource.sourceKind,
          contentType: previousSource.contentType,
          title: candidate.meeting.title,
          contentHash: previousSource.contentHash,
          contentLength: candidate.text.length,
          indexedAt: previousSource.indexedAt,
        ));
        processed++;
        continue;
      }

      var oldSourceRemoved = previousSource == null;
      if (previousSource != null) {
        try {
          await _ragService.removeSource(previousSource.ragSourceId);
          oldSourceRemoved = true;
        } catch (_) {
          failed++;
          nextSources.add(previousSource);
        }
      }

      if (oldSourceRemoved) {
        try {
          final ragSourceId = await _ragService.addSource(
            text: candidate.text,
            title: candidate.meeting.title,
            metadataJson: _metadataJson(candidate.meeting),
          );
          nextSources.add(_indexedSource(
            meeting: candidate.meeting,
            text: candidate.text,
            ragSourceId: ragSourceId,
          ));
        } catch (_) {
          failed++;
        }
      }
      processed++;
    }

    final metadata = LibraryRagMetadata(sources: nextSources);
    await _metadataStore.save(metadata);
    onProgress?.call(LibraryIndexProgress(
      indexedItems: processed,
      totalItems: candidates.length,
      failedItems: failed,
    ));
    return metadata;
  }
```

- [ ] **Step 6: Run repository tests**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/services/library_rag_repository.dart test/services/library_rag_repository_test.dart
git commit -m "feat(rag): sync ask library index incrementally"
```

Expected: commit succeeds.

---

### Task 5: Wire Provider Readiness And Update Action

**Files:**
- Modify: `lib/providers/library_rag_provider.dart`
- Verify: `test/providers/library_rag_provider_test.dart`

- [ ] **Step 1: Keep provider test scope focused**

Do not add new provider tests in this task. The current provider stack combines generated Riverpod settings, `AsyncNotifier` library loading, and a concrete `LibraryRagRepository`; adding test-only abstractions here would be larger than the production change. Repository behavior is covered in Tasks 3 and 4. This task verifies provider integration with analyzer and the existing provider test file.

Run: `flutter test test/providers/library_rag_provider_test.dart`

Expected: PASS before provider edits.

- [ ] **Step 2: Add provider methods**

Modify `lib/providers/library_rag_provider.dart` inside `LibraryRagSetupNotifier`:

```dart
  Future<void> refreshReadiness() async {
    final enabled = ref.read(settingsProvider).localLibraryChatEnabled;
    if (!enabled) {
      state = const LibraryRagSetupState();
      return;
    }
    final library = await ref.read(meetingLibraryProvider.future);
    final inspection = await ref.read(libraryRagRepositoryProvider).inspectIndex(library);
    state = state.copyWith(
      readiness: switch (inspection.status) {
        LibraryIndexInspectionStatus.notIndexed => LibraryRagReadiness.enabledNotIndexed,
        LibraryIndexInspectionStatus.ready => LibraryRagReadiness.ready,
        LibraryIndexInspectionStatus.stale => LibraryRagReadiness.stale,
      },
      clearError: true,
    );
  }

  Future<void> updateIndex() async {
    final previousReadiness = state.readiness;
    final library = await ref.read(meetingLibraryProvider.future);
    state = state.copyWith(readiness: LibraryRagReadiness.indexing, clearError: true);
    try {
      final metadata = await ref.read(libraryRagRepositoryProvider).syncLibrary(
        library,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        readiness: LibraryRagReadiness.ready,
        progress: LibraryIndexProgress(
          indexedItems: metadata.sources.length,
          totalItems: metadata.sources.length,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        readiness: previousReadiness == LibraryRagReadiness.stale
            ? LibraryRagReadiness.stale
            : LibraryRagReadiness.failed,
        error: e.toString(),
      );
    }
  }
```

- [ ] **Step 3: Make initial indexing use incremental sync**

In `indexLibrary()`, replace:

```dart
      await ref.read(libraryRagRepositoryProvider).indexAll(
```

with:

```dart
      await ref.read(libraryRagRepositoryProvider).syncLibrary(
```

This prevents initial re-indexing from accumulating duplicates if metadata already exists.

- [ ] **Step 4: Trigger readiness inspection when Ask Library screen opens**

This wiring can be done in Task 6 inside `AskLibraryScreen.initState()`. Do not trigger async work directly from `build()`.

- [ ] **Step 5: Run provider tests and analyzer for touched provider**

Run: `flutter test test/providers/library_rag_provider_test.dart`

Expected: PASS if provider tests were added or existing tests still pass.

Run: `flutter analyze lib/providers/library_rag_provider.dart`

Expected: no analyzer errors.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/providers/library_rag_provider.dart
git commit -m "feat(rag): expose ask library index update state"
```

Expected: commit succeeds.

---

### Task 6: Add Stale Banner To Ask Library UI

**Files:**
- Modify: `lib/screens/ask_library_screen.dart`
- Optional modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, generated localization files if localizing strings now

- [ ] **Step 1: Add readiness refresh on screen open**

Modify `_AskLibraryScreenState` in `lib/screens/ask_library_screen.dart`:

```dart
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(libraryRagSetupProvider.notifier).refreshReadiness();
    });
  }
```

- [ ] **Step 2: Pass stale/update state into chat view**

In the `ready || stale` branch, replace `_ChatView(...)` with:

```dart
          _ChatView(
            chat: chat,
            controller: _controller,
            scrollController: _scrollController,
            isStale: setup.readiness == LibraryRagReadiness.stale,
            isIndexing: false,
            staleError: setup.error,
            onUpdateIndex: () => ref.read(libraryRagSetupProvider.notifier).updateIndex(),
            onSend: _send,
            onCitationTap: _openCitation,
          ),
```

Keep the existing `LibraryRagReadiness.indexing => _IndexingView(setup: setup)` branch for full-screen indexing during update.

- [ ] **Step 3: Extend `_ChatView` constructor**

Modify `_ChatView` fields and constructor:

```dart
  final bool isStale;
  final bool isIndexing;
  final String? staleError;
  final VoidCallback onUpdateIndex;
```

Constructor parameters:

```dart
    required this.isStale,
    required this.isIndexing,
    required this.staleError,
    required this.onUpdateIndex,
```

- [ ] **Step 4: Render stale banner**

At the start of `_ChatView.build()` column children, before `Expanded`, insert:

```dart
        if (isStale)
          MaterialBanner(
            content: Text(
              staleError == null
                  ? 'Library changed. Answers may miss recent updates.'
                  : 'Library update failed. Answers may miss recent updates.',
            ),
            actions: [
              TextButton(
                onPressed: isIndexing ? null : onUpdateIndex,
                child: const Text('Update index'),
              ),
            ],
          ),
```

- [ ] **Step 5: Disable send while indexing**

Change the send button `onPressed`:

```dart
                  onPressed: chat.isStreaming || isIndexing ? null : onSend,
```

Change `TextField.onSubmitted`:

```dart
                    onSubmitted: chat.isStreaming || isIndexing ? null : (_) => onSend(),
```

- [ ] **Step 6: Run analyzer for UI file**

Run: `flutter analyze lib/screens/ask_library_screen.dart`

Expected: no analyzer errors.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/screens/ask_library_screen.dart
git commit -m "feat(rag): show stale ask library index banner"
```

Expected: commit succeeds.

---

### Task 7: Final Verification

**Files:**
- Verify only unless failures require edits.

- [ ] **Step 1: Run focused repository tests**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: PASS.

- [ ] **Step 2: Run provider tests**

Run: `flutter test test/providers/library_rag_provider_test.dart`

Expected: PASS.

- [ ] **Step 3: Run full Flutter test suite**

Run: `flutter test`

Expected: PASS. If unrelated existing tests fail, record the failing test names and confirm whether failures are related to RAG sync before changing code.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`

Expected: no new analyzer errors. Existing unrelated analyzer issues should be documented separately and not mixed into this feature unless they block compilation of touched files.

- [ ] **Step 5: Inspect final diff**

Run: `git status --short`

Expected: only intended RAG sync files are modified, plus any pre-existing unrelated worktree changes that were present before this plan.

Run: `git diff -- lib/models/library_rag.dart lib/services/library_rag_service.dart lib/services/library_rag_repository.dart lib/providers/library_rag_provider.dart lib/screens/ask_library_screen.dart test/services/library_rag_repository_test.dart test/providers/library_rag_provider_test.dart`

Expected: diff matches this plan and contains no unrelated refactors.

- [ ] **Step 6: Commit verification fixes if needed**

If verification required code changes, commit them:

```bash
git add lib/models/library_rag.dart lib/services/library_rag_service.dart lib/services/library_rag_repository.dart lib/providers/library_rag_provider.dart lib/screens/ask_library_screen.dart test/services/library_rag_repository_test.dart test/providers/library_rag_provider_test.dart
git commit -m "fix(rag): stabilize ask library index sync"
```

Expected: commit succeeds. If no fixes were needed, skip this step.

---

## Manual QA Checklist

- [ ] Enable Local library chat from Settings or Ask Library setup.
- [ ] Index a library with at least one transcript.
- [ ] Ask a question and confirm citations still work.
- [ ] Add or import a new eligible item.
- [ ] Reopen Ask Library and confirm stale banner appears.
- [ ] Ask a question while stale and confirm chat still works.
- [ ] Tap **Update index** and confirm progress appears.
- [ ] Confirm stale banner disappears after update.
- [ ] Change an indexed transcript and confirm update replaces the old source.
- [ ] Archive or delete an indexed item and confirm update removes its citations from future answers.

## Self-Review Notes

- Spec coverage: manual stale prompt, incremental sync, stale chat, remove-before-replace, title-only metadata refresh, and tests are covered.
- Placeholder scan: no implementation step relies on undefined future work.
- Type consistency: `LibraryIndexInspection`, `LibraryIndexInspectionStatus`, `inspectIndex()`, and `syncLibrary()` names are used consistently across tasks.

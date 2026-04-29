import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/library_rag_metadata_store.dart';
import 'package:summsumm/services/library_rag_repository.dart';
import 'package:summsumm/services/library_rag_service.dart';

void main() {
  test('estimate includes transcripts and skips empty content', () async {
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: _MemoryMetadataStore(),
      documentTextExtractor: (_) async => '',
    );

    final estimate = await repository.estimate([
      _meeting(id: 'a', transcript: 'alpha beta gamma'),
      _meeting(id: 'b', transcript: ''),
    ]);

    expect(estimate.meetingCount, 1);
    expect(estimate.documentCount, 0);
    expect(estimate.hasEligibleContent, isTrue);
  });

  test('indexAll stores rag source mapping', () async {
    final client = FakeLibraryRagClient();
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: client),
      metadataStore: store,
      documentTextExtractor: (_) async => '',
    );

    await repository
        .indexAll([_meeting(id: 'a', transcript: 'alpha beta gamma')]);

    final metadata = await store.load();
    expect(metadata.sources.single.libraryItemId, 'a');
    expect(metadata.sources.single.ragSourceId, 1);
    expect(metadata.sources.single.contentType, LibraryContentType.transcript);
  });

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

  test('indexAll reports progress before extracting slow document text',
      () async {
    final extractionStarted = Completer<void>();
    final finishExtraction = Completer<void>();
    final progressEvents = <LibraryIndexProgress>[];
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: _MemoryMetadataStore(),
      documentTextExtractor: (_) async {
        extractionStarted.complete();
        await finishExtraction.future;
        return 'document text';
      },
    );

    final indexing = repository.indexAll(
      [_document(id: 'doc')],
      onProgress: progressEvents.add,
    );
    await extractionStarted.future;

    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last.currentTitle, 'Document doc');

    finishExtraction.complete();
    await indexing;
  });
}

Meeting _meeting({required String id, required String transcript}) => Meeting(
      id: id,
      createdAt: DateTime.utc(2026, 4, 28),
      durationSec: 60,
      audioPath: '/tmp/$id.m4a',
      title: 'Meeting $id',
      rawTranscript: transcript,
      status: MeetingStatus.transcribed,
    );

Meeting _document({required String id}) => Meeting(
      id: id,
      createdAt: DateTime.utc(2026, 4, 28),
      durationSec: 0,
      audioPath: '/tmp/$id.pdf',
      title: 'Document $id',
      status: MeetingStatus.done,
      type: MeetingType.document,
    );

class _MemoryMetadataStore extends LibraryRagMetadataStore {
  LibraryRagMetadata _metadata = const LibraryRagMetadata();

  @override
  Future<LibraryRagMetadata> load() async => _metadata;

  @override
  Future<void> save(LibraryRagMetadata metadata) async {
    _metadata = metadata;
  }

  @override
  Future<void> clear() async {
    _metadata = const LibraryRagMetadata();
  }
}

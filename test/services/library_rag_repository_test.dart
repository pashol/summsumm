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

    await repository.indexAll([_meeting(id: 'a', transcript: 'alpha beta gamma')]);

    final metadata = await store.load();
    expect(metadata.sources.single.libraryItemId, 'a');
    expect(metadata.sources.single.ragSourceId, 99);
    expect(metadata.sources.single.contentType, LibraryContentType.transcript);
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

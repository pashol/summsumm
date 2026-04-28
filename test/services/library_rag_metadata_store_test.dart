import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/services/library_rag_metadata_store.dart';

void main() {
  test('loads empty metadata when file is missing', () async {
    final dir = await Directory.systemTemp.createTemp('rag_metadata_test_');
    addTearDown(() => dir.delete(recursive: true));
    final store = LibraryRagMetadataStore(getBaseDir: () async => dir);

    final metadata = await store.load();

    expect(metadata.sources, isEmpty);
  });

  test('saves and loads metadata', () async {
    final dir = await Directory.systemTemp.createTemp('rag_metadata_test_');
    addTearDown(() => dir.delete(recursive: true));
    final store = LibraryRagMetadataStore(getBaseDir: () async => dir);
    final metadata = LibraryRagMetadata(
      sources: [
        IndexedLibrarySource(
          libraryItemId: 'a',
          ragSourceId: 7,
          sourceKind: LibrarySourceKind.meeting,
          contentType: LibraryContentType.transcript,
          title: 'A',
          contentHash: 'hash',
          contentLength: 100,
          indexedAt: DateTime.utc(2026, 4, 28),
        ),
      ],
    );

    await store.save(metadata);
    final loaded = await store.load();

    expect(loaded.sources.single.libraryItemId, 'a');
    expect(loaded.sources.single.ragSourceId, 7);
  });

  test('clear removes metadata file', () async {
    final dir = await Directory.systemTemp.createTemp('rag_metadata_test_');
    addTearDown(() => dir.delete(recursive: true));
    final store = LibraryRagMetadataStore(getBaseDir: () async => dir);

    await store.save(const LibraryRagMetadata());
    await store.clear();
    final loaded = await store.load();

    expect(loaded.sources, isEmpty);
  });
}

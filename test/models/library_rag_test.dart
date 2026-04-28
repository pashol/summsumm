import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';

void main() {
  test('IndexedLibrarySource round trips json', () {
    final source = IndexedLibrarySource(
      libraryItemId: 'meeting-1',
      ragSourceId: 42,
      sourceKind: LibrarySourceKind.meeting,
      contentType: LibraryContentType.transcript,
      title: 'Planning',
      contentHash: 'abc123',
      contentLength: 1200,
      indexedAt: DateTime.utc(2026, 4, 28),
    );

    final decoded = IndexedLibrarySource.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.libraryItemId, 'meeting-1');
    expect(decoded.ragSourceId, 42);
    expect(decoded.sourceKind, LibrarySourceKind.meeting);
    expect(decoded.contentType, LibraryContentType.transcript);
    expect(decoded.indexedAt, DateTime.utc(2026, 4, 28));
  });

  test('IndexEstimate reports whether there is eligible content', () {
    const empty = LibraryIndexEstimate(
      meetingCount: 0,
      documentCount: 0,
      totalTextBytes: 0,
      estimatedChunks: 0,
    );
    const nonEmpty = LibraryIndexEstimate(
      meetingCount: 1,
      documentCount: 1,
      totalTextBytes: 5000,
      estimatedChunks: 10,
    );

    expect(empty.hasEligibleContent, isFalse);
    expect(nonEmpty.hasEligibleContent, isTrue);
  });
}

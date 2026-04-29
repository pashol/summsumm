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

  test('LibraryIndexInspection.hasUsableIndex is false when indexedItems is zero', () {
    const notIndexed = LibraryIndexInspection(
      status: LibraryIndexInspectionStatus.notIndexed,
      eligibleItems: 5,
      indexedItems: 0,
      staleItems: 0,
    );

    expect(notIndexed.hasUsableIndex, isFalse);
  });

  test('LibraryIndexInspection supports all statuses', () {
    const notIndexed = LibraryIndexInspection(
      status: LibraryIndexInspectionStatus.notIndexed,
      eligibleItems: 5,
      indexedItems: 0,
      staleItems: 0,
    );
    const ready = LibraryIndexInspection(
      status: LibraryIndexInspectionStatus.ready,
      eligibleItems: 5,
      indexedItems: 5,
      staleItems: 0,
    );
    const stale = LibraryIndexInspection(
      status: LibraryIndexInspectionStatus.stale,
      eligibleItems: 5,
      indexedItems: 3,
      staleItems: 2,
    );

    expect(notIndexed.status, LibraryIndexInspectionStatus.notIndexed);
    expect(ready.status, LibraryIndexInspectionStatus.ready);
    expect(stale.status, LibraryIndexInspectionStatus.stale);
    expect(ready.hasUsableIndex, isTrue);
    expect(stale.hasUsableIndex, isTrue);
  });
}

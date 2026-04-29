import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mobile_rag_engine/src/rust/api/document_parser.dart'
    as doc_parser;

import '../models/library_rag.dart';
import '../models/meeting.dart';
import 'library_rag_metadata_store.dart';
import 'library_rag_service.dart';

typedef DocumentTextExtractor = Future<String> Function(String path);

Future<String> _defaultDocumentTextExtractor(String path) =>
    doc_parser.extractTextFromFile(filePath: path);

class LibraryRagRepository {
  final LibraryRagService _ragService;
  final LibraryRagMetadataStore _metadataStore;
  final DocumentTextExtractor _documentTextExtractor;

  LibraryRagRepository({
    required LibraryRagService ragService,
    required LibraryRagMetadataStore metadataStore,
    DocumentTextExtractor? documentTextExtractor,
  })  : _ragService = ragService,
        _metadataStore = metadataStore,
        _documentTextExtractor =
            documentTextExtractor ?? _defaultDocumentTextExtractor;

  Future<LibraryIndexEstimate> estimate(List<Meeting> meetings) async {
    var meetingCount = 0;
    var documentCount = 0;
    var totalBytes = 0;

    for (final meeting in meetings) {
      final text = await _textFor(meeting);
      if (text.trim().isEmpty) continue;
      totalBytes += utf8.encode(text).length;
      if (meeting.type == MeetingType.document) {
        documentCount++;
      } else {
        meetingCount++;
      }
    }

    return LibraryIndexEstimate(
      meetingCount: meetingCount,
      documentCount: documentCount,
      totalTextBytes: totalBytes,
      estimatedChunks: (totalBytes / 500).ceil(),
    );
  }

  Future<LibraryRagMetadata> indexAll(
    List<Meeting> meetings, {
    void Function(LibraryIndexProgress progress)? onProgress,
  }) async {
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

    final indexed = <IndexedLibrarySource>[];
    var failed = 0;
    for (var i = 0; i < eligible.length; i++) {
      final candidate = eligible[i];
      onProgress?.call(LibraryIndexProgress(
        indexedItems: i,
        totalItems: eligible.length,
        failedItems: failed,
        currentTitle: candidate.meeting.title,
      ));

      try {
        final sourceKind = candidate.meeting.type == MeetingType.document
            ? LibrarySourceKind.document
            : LibrarySourceKind.meeting;
        final contentType = candidate.meeting.type == MeetingType.document
            ? LibraryContentType.document
            : LibraryContentType.transcript;
        final sourceMetadata = {
          'libraryItemId': candidate.meeting.id,
          'sourceKind': sourceKind.name,
          'contentType': contentType.name,
          'title': candidate.meeting.title,
          'createdAt': candidate.meeting.createdAt.toUtc().toIso8601String(),
        };
        final ragSourceId = await _ragService.addSource(
          text: candidate.text,
          title: candidate.meeting.title,
          metadataJson: jsonEncode(sourceMetadata),
        );
        indexed.add(IndexedLibrarySource(
          libraryItemId: candidate.meeting.id,
          ragSourceId: ragSourceId,
          sourceKind: sourceKind,
          contentType: contentType,
          title: candidate.meeting.title,
          contentHash: _hash(candidate.text),
          contentLength: candidate.text.length,
          indexedAt: DateTime.now().toUtc(),
        ));
      } catch (_) {
        failed++;
      }
    }

    final metadata = LibraryRagMetadata(sources: indexed);
    await _metadataStore.save(metadata);
    onProgress?.call(LibraryIndexProgress(
      indexedItems: indexed.length,
      totalItems: eligible.length,
      failedItems: failed,
    ));
    return metadata;
  }

  Future<LibraryRagSearchResult> search(String query) =>
      _ragService.search(query);

  Future<LibraryRagMetadata> loadMetadata() => _metadataStore.load();

  Future<LibraryIndexInspection> inspectIndex(List<Meeting> meetings) async {
    final metadata = await _metadataStore.load();
    final candidates = await _eligibleCandidates(meetings);
    final activeIds = candidates.map((candidate) => candidate.meeting.id).toSet();
    final metadataByItem = {
      for (final source in metadata.sources) source.libraryItemId: source,
    };

    var indexedItems = metadata.sources.length;
    var staleItems = 0;

    for (final candidate in candidates) {
      final source = metadataByItem[candidate.meeting.id];
      if (source == null) {
        staleItems++;
        continue;
      }
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

  Future<List<_IndexCandidate>> _eligibleCandidates(List<Meeting> meetings) async {
    final eligible = <_IndexCandidate>[];
    for (final meeting in meetings) {
      final text = await _textFor(meeting);
      if (text.trim().isEmpty) continue;
      eligible.add(_IndexCandidate(meeting: meeting, text: text));
    }
    return eligible;
  }

  Future<String> _textFor(Meeting meeting) async {
    if (meeting.type == MeetingType.document) {
      if (meeting.audioPath.isEmpty) return '';
      return _documentTextExtractor(meeting.audioPath);
    }
    return meeting.transcript ?? '';
  }

  String _hash(String text) => sha256.convert(utf8.encode(text)).toString();
}

class _IndexCandidate {
  final Meeting meeting;
  final String text;

  const _IndexCandidate({required this.meeting, required this.text});
}

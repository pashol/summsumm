import 'dart:convert';

enum LibraryRagReadiness {
  disabled,
  enabledNotIndexed,
  indexing,
  ready,
  stale,
  failed,
}

enum LibrarySourceKind { meeting, document }

enum LibraryContentType { transcript, document }

class LibraryIndexEstimate {
  final int meetingCount;
  final int documentCount;
  final int totalTextBytes;
  final int estimatedChunks;

  const LibraryIndexEstimate({
    required this.meetingCount,
    required this.documentCount,
    required this.totalTextBytes,
    required this.estimatedChunks,
  });

  bool get hasEligibleContent => meetingCount + documentCount > 0;
}

class LibraryIndexProgress {
  final int indexedItems;
  final int totalItems;
  final int failedItems;
  final String? currentTitle;

  const LibraryIndexProgress({
    this.indexedItems = 0,
    this.totalItems = 0,
    this.failedItems = 0,
    this.currentTitle,
  });

  double? get fraction => totalItems == 0 ? null : indexedItems / totalItems;
}

class IndexedLibrarySource {
  final String libraryItemId;
  final int ragSourceId;
  final LibrarySourceKind sourceKind;
  final LibraryContentType contentType;
  final String title;
  final String contentHash;
  final int contentLength;
  final DateTime indexedAt;

  const IndexedLibrarySource({
    required this.libraryItemId,
    required this.ragSourceId,
    required this.sourceKind,
    required this.contentType,
    required this.title,
    required this.contentHash,
    required this.contentLength,
    required this.indexedAt,
  });

  Map<String, dynamic> toJson() => {
        'libraryItemId': libraryItemId,
        'ragSourceId': ragSourceId,
        'sourceKind': sourceKind.name,
        'contentType': contentType.name,
        'title': title,
        'contentHash': contentHash,
        'contentLength': contentLength,
        'indexedAt': indexedAt.toUtc().toIso8601String(),
      };

  factory IndexedLibrarySource.fromJson(Map<String, dynamic> json) {
    return IndexedLibrarySource(
      libraryItemId: json['libraryItemId'] as String,
      ragSourceId: (json['ragSourceId'] as num).toInt(),
      sourceKind: LibrarySourceKind.values.byName(json['sourceKind'] as String),
      contentType: LibraryContentType.values.byName(json['contentType'] as String),
      title: json['title'] as String? ?? 'Untitled',
      contentHash: json['contentHash'] as String? ?? '',
      contentLength: (json['contentLength'] as num?)?.toInt() ?? 0,
      indexedAt: DateTime.parse(json['indexedAt'] as String).toUtc(),
    );
  }
}

class LibraryRagMetadata {
  final List<IndexedLibrarySource> sources;

  const LibraryRagMetadata({this.sources = const []});

  IndexedLibrarySource? sourceForLibraryItem(String id) {
    for (final source in sources) {
      if (source.libraryItemId == id) return source;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'sources': sources.map((source) => source.toJson()).toList(),
      };

  factory LibraryRagMetadata.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    return LibraryRagMetadata(
      sources: rawSources is List
          ? rawSources
              .map((source) => IndexedLibrarySource.fromJson(source as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LibraryRagMetadata.fromJsonString(String value) =>
      LibraryRagMetadata.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

class LibraryCitation {
  final String libraryItemId;
  final String title;
  final LibrarySourceKind sourceKind;
  final LibraryContentType contentType;
  final String? excerpt;

  const LibraryCitation({
    required this.libraryItemId,
    required this.title,
    required this.sourceKind,
    required this.contentType,
    this.excerpt,
  });
}

class AskLibraryMessage {
  final String role;
  final String content;
  final List<LibraryCitation> citations;

  const AskLibraryMessage({
    required this.role,
    required this.content,
    this.citations = const [],
  });
}

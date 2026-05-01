import 'package:mobile_rag_engine/mobile_rag_engine.dart';

class LibraryRagSearchChunk {
  final int sourceId;
  final String content;
  final String? metadata;

  const LibraryRagSearchChunk({
    required this.sourceId,
    required this.content,
    this.metadata,
  });
}

class LibraryRagSearchResult {
  final String contextText;
  final List<LibraryRagSearchChunk> chunks;

  const LibraryRagSearchResult({
    required this.contextText,
    required this.chunks,
  });
}

abstract class LibraryRagClient {
  Future<void> initialize();
  Future<int> addDocument(String text, {required String name, required String metadata});
  Future<void> removeSource(int sourceId);
  Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds});
  Future<void> clearAllData();
}

class MobileLibraryRagClient implements LibraryRagClient {
  @override
  Future<void> initialize() async {
    if (MobileRag.isInitialized) return;
    await MobileRag.initialize(
      tokenizerAsset: 'assets/rag/tokenizer.json',
      modelAsset: 'assets/rag/model.onnx',
      databaseName: 'library_rag.sqlite',
      threadLevel: ThreadUseLevel.medium,
      deferIndexWarmup: true,
    );
  }

  @override
  Future<int> addDocument(String text, {required String name, required String metadata}) async {
    final result = await MobileRag.instance.addDocument(
      text,
      name: name,
      metadata: metadata,
    );
    return result.sourceId;
  }

  @override
  Future<void> removeSource(int sourceId) => MobileRag.instance.removeSource(sourceId);

  @override
  Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async {
    if (!MobileRag.instance.isIndexReady) {
      await MobileRag.instance.warmupFuture;
    }
    final result = await MobileRag.instance.searchHybridWithContext(
      query,
      topK: 12,
      tokenBudget: 3000,
      adjacentChunks: 1,
      sourceIds: sourceIds,
    );
    return LibraryRagSearchResult(
      contextText: result.context.text,
      chunks: result.chunks
          .map(
            (chunk) => LibraryRagSearchChunk(
              sourceId: chunk.sourceId,
              content: chunk.content,
              metadata: chunk.metadata,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> clearAllData() => MobileRag.instance.clearAllData();
}

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

class FakeLibraryRagClient implements LibraryRagClient {
  int initializeCalls = 0;
  int nextSourceId = 1;
  String? lastText;
  String? lastName;
  String? lastMetadata;
  final List<FakeLibraryRagDocument> addedDocuments = [];
  final List<int> removedSourceIds = [];
  bool throwOnRemoveSource = false;
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
    ),);
    return sourceId;
  }

  @override
  Future<void> removeSource(int sourceId) async {
    if (throwOnRemoveSource) throw Exception('removeSource failed');
    removedSourceIds.add(sourceId);
  }

  @override
  Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async => searchResult;

  @override
  Future<void> clearAllData() async {}
}

class LibraryRagService {
  final LibraryRagClient _client;
  bool _initialized = false;

  LibraryRagService({LibraryRagClient? client})
      : _client = client ?? MobileLibraryRagClient();

  Future<void> initialize() async {
    if (_initialized) return;
    await _client.initialize();
    _initialized = true;
  }

  Future<int> addSource({
    required String text,
    required String title,
    required String metadataJson,
  }) async {
    await initialize();
    return _client.addDocument(text, name: title, metadata: metadataJson);
  }

  Future<void> removeSource(int sourceId) async {
    await initialize();
    await _client.removeSource(sourceId);
  }

  Future<LibraryRagSearchResult> search(String query, {List<int>? sourceIds}) async {
    await initialize();
    return _client.search(query, sourceIds: sourceIds);
  }

  Future<void> clearAllData() async {
    await initialize();
    await _client.clearAllData();
  }
}

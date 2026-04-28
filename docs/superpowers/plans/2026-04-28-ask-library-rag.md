# Ask Library RAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an opt-in `Ask Library` screen that indexes eligible library transcripts/documents with `mobile_rag_engine`, retrieves relevant context locally, streams AI answers, and displays tappable citations.

**Architecture:** Add a focused RAG layer behind `LibraryRagService` and `LibraryRagRepository`, expose state through Riverpod providers, and keep widgets limited to setup/chat/citation UI. Persist app-level RAG source mappings in a JSON metadata file while `mobile_rag_engine` owns its SQLite/HNSW data.

**Tech Stack:** Flutter, Riverpod, SharedPreferences-backed `AppSettings`, `mobile_rag_engine: ^0.17.0`, `path_provider`, existing `AiService`, existing JSON-file meeting repository.

---

## File Structure

- Modify: `pubspec.yaml` to add `mobile_rag_engine` and RAG model assets.
- Add: `assets/rag/model.onnx` and `assets/rag/tokenizer.json` from the validated MiniLM URLs in the spec.
- Modify: `lib/models/app_settings.dart` to persist `localLibraryChatEnabled`.
- Modify: `lib/providers/settings_provider.dart` to add `setLocalLibraryChatEnabled()`.
- Add: `lib/models/library_rag.dart` for readiness, estimates, metadata mappings, citations, and chat messages.
- Add: `lib/services/library_rag_metadata_store.dart` for JSON mapping persistence.
- Add: `lib/services/library_rag_service.dart` as the only app wrapper around `mobile_rag_engine`.
- Add: `lib/services/library_rag_repository.dart` for eligibility, estimates, indexing, stale detection, retrieval, and citation mapping.
- Add: `lib/providers/library_rag_provider.dart` for setup/index readiness state and indexing actions.
- Add: `lib/providers/ask_library_chat_provider.dart` for global chat streaming state.
- Add: `lib/screens/ask_library_screen.dart` for setup, indexing, chat, and citation UI.
- Modify: `lib/screens/meeting_library_screen.dart` to add the `Ask Library` entry.
- Modify: `lib/screens/meeting_detail_screen.dart` to accept `initialTabIndex` and support Transcript-tab navigation.
- Modify: `lib/screens/settings_screen.dart` to show the local library chat setting/status.
- Modify: `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`; regenerate localization classes.
- Test: `test/models/app_settings_test.dart`.
- Test: `test/services/library_rag_metadata_store_test.dart`.
- Test: `test/services/library_rag_repository_test.dart`.
- Test: `test/providers/ask_library_chat_provider_test.dart`.
- Test: `test/screens/ask_library_screen_test.dart`.
- Modify: `test/screens/meeting_detail_screen_test.dart` for initial tab behavior.

---

### Task 1: Wire Dependency, Assets, And Settings Flag

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/models/app_settings.dart`
- Modify: `lib/providers/settings_provider.dart`
- Test: `test/models/app_settings_test.dart`

- [ ] **Step 1: Add a failing settings test**

Create `test/models/app_settings_test.dart`. If the file already exists, add these tests to the existing `main()` body:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';

void main() {
  test('defaults disable local library chat', () {
    const settings = AppSettings.defaults();

    expect(settings.localLibraryChatEnabled, isFalse);
  });

  test('serializes local library chat setting', () {
    const settings = AppSettings.defaults();
    final enabled = settings.copyWith(localLibraryChatEnabled: true);

    final decoded = AppSettings.fromJson(enabled.toJson());

    expect(decoded.localLibraryChatEnabled, isTrue);
  });

  test('missing local library chat setting migrates to disabled', () {
    final decoded = AppSettings.fromJson(const {
      'provider': 'openrouter',
      'openrouterModel': '',
      'openaiModel': '',
      'language': 'Same as input',
      'summaryStyle': 'structured',
      'ttsSpeed': 1.0,
    });

    expect(decoded.localLibraryChatEnabled, isFalse);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/models/app_settings_test.dart`

Expected: FAIL with errors that `localLibraryChatEnabled` and the `copyWith` named parameter are not defined.

- [ ] **Step 3: Add dependency and assets to `pubspec.yaml`**

Add the dependency under `dependencies:`:

```yaml
  mobile_rag_engine: ^0.17.0
```

Add assets under `flutter:` while preserving `uses-material-design` and `generate`:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/rag/model.onnx
    - assets/rag/tokenizer.json
```

- [ ] **Step 4: Download model assets**

Run: `mkdir -p assets/rag`

Run: `curl -L -o assets/rag/model.onnx "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model_qint8_arm64.onnx"`

Run: `curl -L -o assets/rag/tokenizer.json "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer.json"`

Expected: both files exist and `assets/rag/model.onnx` is roughly 23 MB.

- [ ] **Step 5: Implement `AppSettings.localLibraryChatEnabled`**

Modify `lib/models/app_settings.dart`:

```dart
class AppSettings {
  final String provider;
  final String openrouterModel;
  final String openaiModel;
  final String language;
  final String summaryStyle;
  final double ttsSpeed;
  final String openaiKey;
  final String openrouterKey;
  final bool debugMode;
  final String? localeOverride;
  final TranscriptionStrategy transcriptionStrategy;
  final ModelSize onDeviceModelSize;
  final bool enableRealTimeTranscription;
  final bool onDeviceDiarization;
  final String streamingModelLanguage;
  final bool compressAudioStorage;
  final bool localLibraryChatEnabled;
  final Map<String, String> promptOverrides;
  final List<CustomPrompt> customPrompts;
  final String? selectedCustomPromptId;
```

Add the constructor parameter with default:

```dart
    this.compressAudioStorage = false,
    this.localLibraryChatEnabled = false,
    this.promptOverrides = const {},
```

Add to `copyWith`:

```dart
    bool? compressAudioStorage,
    bool? localLibraryChatEnabled,
    Map<String, String>? promptOverrides,
```

Set it in the returned `AppSettings`:

```dart
        compressAudioStorage: compressAudioStorage ?? this.compressAudioStorage,
        localLibraryChatEnabled:
            localLibraryChatEnabled ?? this.localLibraryChatEnabled,
        promptOverrides: promptOverrides ?? this.promptOverrides,
```

Add to `toJson()`:

```dart
        'localLibraryChatEnabled': localLibraryChatEnabled,
```

Add to `fromJson()`:

```dart
        localLibraryChatEnabled:
            json['localLibraryChatEnabled'] as bool? ?? false,
```

Add to equality:

```dart
        other.localLibraryChatEnabled == localLibraryChatEnabled &&
```

Add to `hashCode` before `promptOverrides`:

```dart
        localLibraryChatEnabled,
```

- [ ] **Step 6: Add settings provider setter**

Modify `lib/providers/settings_provider.dart`:

```dart
  Future<void> setLocalLibraryChatEnabled(bool enabled) async {
    final next = state.copyWith(localLibraryChatEnabled: enabled);
    state = next;
    await _persist(next);
  }
```

- [ ] **Step 7: Fetch dependencies and run settings test**

Run: `flutter pub get`

Expected: succeeds and updates `pubspec.lock`.

Run: `flutter test test/models/app_settings_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add pubspec.yaml pubspec.lock assets/rag/model.onnx assets/rag/tokenizer.json lib/models/app_settings.dart lib/providers/settings_provider.dart test/models/app_settings_test.dart
git commit -m "feat(rag): add local library chat setting and assets"
```

---

### Task 2: Add RAG Domain Models

**Files:**
- Create: `lib/models/library_rag.dart`
- Test: `test/models/library_rag_test.dart`

- [ ] **Step 1: Write failing model tests**

Create `test/models/library_rag_test.dart`:

```dart
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
```

- [ ] **Step 2: Run model tests and verify they fail**

Run: `flutter test test/models/library_rag_test.dart`

Expected: FAIL because `library_rag.dart` does not exist.

- [ ] **Step 3: Implement `lib/models/library_rag.dart`**

Create the file:

```dart
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
```

- [ ] **Step 4: Run model tests**

Run: `flutter test test/models/library_rag_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/models/library_rag.dart test/models/library_rag_test.dart
git commit -m "feat(rag): add library rag domain models"
```

---

### Task 3: Persist RAG Source Metadata

**Files:**
- Create: `lib/services/library_rag_metadata_store.dart`
- Test: `test/services/library_rag_metadata_store_test.dart`

- [ ] **Step 1: Write failing metadata store tests**

Create `test/services/library_rag_metadata_store_test.dart`:

```dart
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
```

- [ ] **Step 2: Run metadata tests and verify they fail**

Run: `flutter test test/services/library_rag_metadata_store_test.dart`

Expected: FAIL because `LibraryRagMetadataStore` does not exist.

- [ ] **Step 3: Implement metadata store**

Create `lib/services/library_rag_metadata_store.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/library_rag.dart';

class LibraryRagMetadataStore {
  final Future<Directory> Function()? _getBaseDir;

  LibraryRagMetadataStore({Future<Directory> Function()? getBaseDir})
      : _getBaseDir = getBaseDir;

  Future<File> _file() async {
    final baseDir = _getBaseDir == null
        ? await getApplicationDocumentsDirectory()
        : await _getBaseDir!();
    final dir = Directory(p.join(baseDir.path, 'rag'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'library_rag_metadata.json'));
  }

  Future<LibraryRagMetadata> load() async {
    final file = await _file();
    if (!await file.exists()) return const LibraryRagMetadata();
    try {
      return LibraryRagMetadata.fromJsonString(await file.readAsString());
    } catch (_) {
      return const LibraryRagMetadata();
    }
  }

  Future<void> save(LibraryRagMetadata metadata) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(metadata.toJsonString());
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

- [ ] **Step 4: Run metadata tests**

Run: `flutter test test/services/library_rag_metadata_store_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/services/library_rag_metadata_store.dart test/services/library_rag_metadata_store_test.dart
git commit -m "feat(rag): persist library rag metadata"
```

---

### Task 4: Wrap `mobile_rag_engine` In A Service

**Files:**
- Create: `lib/services/library_rag_service.dart`
- Test: `test/services/library_rag_service_test.dart`

- [ ] **Step 1: Write service tests using a fake client**

Create `test/services/library_rag_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/library_rag_service.dart';

void main() {
  test('initialize is idempotent', () async {
    final client = FakeLibraryRagClient();
    final service = LibraryRagService(client: client);

    await service.initialize();
    await service.initialize();

    expect(client.initializeCalls, 1);
  });

  test('addSource delegates metadata and title', () async {
    final client = FakeLibraryRagClient();
    final service = LibraryRagService(client: client);

    final id = await service.addSource(
      text: 'hello world',
      title: 'Greeting',
      metadataJson: '{"id":"a"}',
    );

    expect(id, 99);
    expect(client.lastText, 'hello world');
    expect(client.lastName, 'Greeting');
    expect(client.lastMetadata, '{"id":"a"}');
  });
}
```

- [ ] **Step 2: Run service tests and verify they fail**

Run: `flutter test test/services/library_rag_service_test.dart`

Expected: FAIL because `LibraryRagService` does not exist.

- [ ] **Step 3: Implement the service and fake client seam**

Create `lib/services/library_rag_service.dart`:

```dart
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
  Future<LibraryRagSearchResult> search(String query);
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
  Future<LibraryRagSearchResult> search(String query) async {
    if (!MobileRag.instance.isIndexReady) {
      await MobileRag.instance.warmupFuture;
    }
    final result = await MobileRag.instance.searchHybridWithContext(
      query,
      topK: 12,
      tokenBudget: 3000,
      adjacentChunks: 1,
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

class FakeLibraryRagClient implements LibraryRagClient {
  int initializeCalls = 0;
  String? lastText;
  String? lastName;
  String? lastMetadata;
  LibraryRagSearchResult searchResult = const LibraryRagSearchResult(
    contextText: '',
    chunks: [],
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<int> addDocument(String text, {required String name, required String metadata}) async {
    lastText = text;
    lastName = name;
    lastMetadata = metadata;
    return 99;
  }

  @override
  Future<void> removeSource(int sourceId) async {}

  @override
  Future<LibraryRagSearchResult> search(String query) async => searchResult;

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

  Future<LibraryRagSearchResult> search(String query) async {
    await initialize();
    return _client.search(query);
  }

  Future<void> clearAllData() async {
    await initialize();
    await _client.clearAllData();
  }
}
```

- [ ] **Step 4: Run service tests**

Run: `flutter test test/services/library_rag_service_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/services/library_rag_service.dart test/services/library_rag_service_test.dart
git commit -m "feat(rag): wrap mobile rag engine"
```

---

### Task 5: Implement RAG Repository Estimates And Indexing

**Files:**
- Create: `lib/services/library_rag_repository.dart`
- Test: `test/services/library_rag_repository_test.dart`

- [ ] **Step 1: Write repository tests**

Create `test/services/library_rag_repository_test.dart` with tests for estimate and indexing:

```dart
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
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: FAIL because `LibraryRagRepository` does not exist.

- [ ] **Step 3: Implement repository**

Create `lib/services/library_rag_repository.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart' show extractTextFromFile;

import '../models/library_rag.dart';
import '../models/meeting.dart';
import 'library_rag_metadata_store.dart';
import 'library_rag_service.dart';

typedef DocumentTextExtractor = Future<String> Function(String path);

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
        _documentTextExtractor = documentTextExtractor ?? extractTextFromFile;

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
    for (final meeting in meetings) {
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

  Future<LibraryRagSearchResult> search(String query) => _ragService.search(query);

  Future<LibraryRagMetadata> loadMetadata() => _metadataStore.load();

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
```

- [ ] **Step 4: Add direct `crypto` dependency**

Add under `dependencies:`:

```yaml
  crypto: ^3.0.6
```

Run: `flutter pub get`

- [ ] **Step 5: Run repository tests**

Run: `flutter test test/services/library_rag_repository_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add pubspec.yaml pubspec.lock lib/services/library_rag_repository.dart test/services/library_rag_repository_test.dart
git commit -m "feat(rag): estimate and index library sources"
```

---

### Task 6: Add Setup And Indexing Providers

**Files:**
- Create: `lib/providers/library_rag_provider.dart`
- Test: `test/providers/library_rag_provider_test.dart`

- [ ] **Step 1: Write provider tests**

Create `test/providers/library_rag_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/library_rag_provider.dart';

void main() {
  test('initial state is disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(libraryRagSetupProvider);

    expect(state.readiness, LibraryRagReadiness.disabled);
  });
}
```

- [ ] **Step 2: Run provider test and verify it fails**

Run: `flutter test test/providers/library_rag_provider_test.dart`

Expected: FAIL because provider file does not exist.

- [ ] **Step 3: Implement setup provider**

Create `lib/providers/library_rag_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_rag.dart';
import '../providers/meeting_library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/library_rag_metadata_store.dart';
import '../services/library_rag_repository.dart';
import '../services/library_rag_service.dart';

final libraryRagServiceProvider = Provider<LibraryRagService>((ref) {
  return LibraryRagService();
});

final libraryRagMetadataStoreProvider = Provider<LibraryRagMetadataStore>((ref) {
  return LibraryRagMetadataStore();
});

final libraryRagRepositoryProvider = Provider<LibraryRagRepository>((ref) {
  return LibraryRagRepository(
    ragService: ref.watch(libraryRagServiceProvider),
    metadataStore: ref.watch(libraryRagMetadataStoreProvider),
  );
});

class LibraryRagSetupState {
  final LibraryRagReadiness readiness;
  final LibraryIndexEstimate? estimate;
  final LibraryIndexProgress? progress;
  final String? error;

  const LibraryRagSetupState({
    this.readiness = LibraryRagReadiness.disabled,
    this.estimate,
    this.progress,
    this.error,
  });

  LibraryRagSetupState copyWith({
    LibraryRagReadiness? readiness,
    LibraryIndexEstimate? estimate,
    LibraryIndexProgress? progress,
    String? error,
    bool clearError = false,
  }) {
    return LibraryRagSetupState(
      readiness: readiness ?? this.readiness,
      estimate: estimate ?? this.estimate,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LibraryRagSetupNotifier extends Notifier<LibraryRagSetupState> {
  @override
  LibraryRagSetupState build() {
    final enabled = ref.watch(settingsProvider).localLibraryChatEnabled;
    if (!enabled) return const LibraryRagSetupState();
    return const LibraryRagSetupState(readiness: LibraryRagReadiness.enabledNotIndexed);
  }

  Future<void> loadEstimate() async {
    final library = await ref.read(meetingLibraryProvider.future);
    final estimate = await ref.read(libraryRagRepositoryProvider).estimate(library);
    state = state.copyWith(estimate: estimate, clearError: true);
  }

  Future<void> enableAndEstimate() async {
    await ref.read(settingsProvider.notifier).setLocalLibraryChatEnabled(true);
    state = state.copyWith(readiness: LibraryRagReadiness.enabledNotIndexed, clearError: true);
    await loadEstimate();
  }

  Future<void> indexLibrary() async {
    final library = await ref.read(meetingLibraryProvider.future);
    state = state.copyWith(readiness: LibraryRagReadiness.indexing, clearError: true);
    try {
      await ref.read(libraryRagRepositoryProvider).indexAll(
        library,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(readiness: LibraryRagReadiness.ready);
    } catch (e) {
      state = state.copyWith(
        readiness: LibraryRagReadiness.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> disable() async {
    await ref.read(settingsProvider.notifier).setLocalLibraryChatEnabled(false);
    state = const LibraryRagSetupState();
  }
}

final libraryRagSetupProvider =
    NotifierProvider<LibraryRagSetupNotifier, LibraryRagSetupState>(
  LibraryRagSetupNotifier.new,
);
```

- [ ] **Step 4: Run provider test**

Run: `flutter test test/providers/library_rag_provider_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/providers/library_rag_provider.dart test/providers/library_rag_provider_test.dart
git commit -m "feat(rag): add library rag setup provider"
```

---

### Task 7: Add Ask Library Chat Provider

**Files:**
- Create: `lib/providers/ask_library_chat_provider.dart`
- Test: `test/providers/ask_library_chat_provider_test.dart`

- [ ] **Step 1: Write chat provider test**

Create `test/providers/ask_library_chat_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/providers/ask_library_chat_provider.dart';

void main() {
  test('initial chat state is empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(askLibraryChatProvider);

    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);
  });
}
```

- [ ] **Step 2: Run chat provider test and verify it fails**

Run: `flutter test test/providers/ask_library_chat_provider_test.dart`

Expected: FAIL because provider file does not exist.

- [ ] **Step 3: Implement chat provider**

Create `lib/providers/ask_library_chat_provider.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/library_rag.dart';
import '../providers/library_rag_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

class AskLibraryChatState {
  final List<AskLibraryMessage> messages;
  final bool isStreaming;
  final String? error;

  const AskLibraryChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  AskLibraryChatState copyWith({
    List<AskLibraryMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) {
    return AskLibraryChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AskLibraryChatNotifier extends StateNotifier<AskLibraryChatState> {
  final Ref _ref;
  StreamSubscription<String>? _streamSub;
  bool _mounted = true;

  AskLibraryChatNotifier(this._ref) : super(const AskLibraryChatState());

  Future<void> sendMessage(String question) async {
    final trimmed = question.trim();
    if (state.isStreaming || trimmed.isEmpty) return;

    final userMessage = AskLibraryMessage(role: 'user', content: trimmed);
    const assistantMessage = AskLibraryMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isStreaming: true,
      clearError: true,
    );

    try {
      final repository = _ref.read(libraryRagRepositoryProvider);
      final search = await repository.search(trimmed);
      if (search.contextText.trim().isEmpty) {
        final updated = List<AskLibraryMessage>.from(state.messages);
        updated[updated.length - 1] = const AskLibraryMessage(
          role: 'assistant',
          content: 'I could not find enough relevant context in your library to answer that.',
        );
        state = state.copyWith(messages: updated, isStreaming: false);
        return;
      }

      final citations = await _citationsForSearch(search);
      final settings = _ref.read(settingsProvider);
      final apiKey = await _ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
      final apiMessages = [
        {
          'role': 'system',
          'content': 'You answer questions using only the provided library context. If the context does not support an answer, say you could not find enough information. Keep answers concise and cite source labels when useful.',
        },
        {
          'role': 'user',
          'content': 'Library context:\n${search.contextText}\n\nQuestion: $trimmed',
        },
      ];

      final stream = _ref.read(aiServiceProvider).streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: apiMessages,
            provider: settings.provider,
          );

      var accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<AskLibraryMessage>.from(state.messages);
          updated[updated.length - 1] = AskLibraryMessage(
            role: 'assistant',
            content: accumulated,
            citations: citations,
          );
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) {
          if (!_mounted) return;
          final updated = List<AskLibraryMessage>.from(state.messages)..removeLast();
          state = state.copyWith(
            messages: updated,
            isStreaming: false,
            error: e is AiException ? e.message : e.toString(),
          );
        },
        onDone: () {
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final updated = List<AskLibraryMessage>.from(state.messages)..removeLast();
      state = state.copyWith(
        messages: updated,
        isStreaming: false,
        error: e is AiException ? e.message : e.toString(),
      );
    }
  }

  Future<List<LibraryCitation>> _citationsForSearch(search) async {
    final seen = <String>{};
    final citations = <LibraryCitation>[];
    for (final chunk in search.chunks) {
      final metadataJson = chunk.metadata;
      if (metadataJson == null || metadataJson.isEmpty) continue;
      final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
      final id = decoded['libraryItemId'] as String?;
      if (id == null || !seen.add(id)) continue;
      citations.add(LibraryCitation(
        libraryItemId: id,
        title: decoded['title'] as String? ?? 'Untitled',
        sourceKind: LibrarySourceKind.values.byName(decoded['sourceKind'] as String),
        contentType: LibraryContentType.values.byName(decoded['contentType'] as String),
        excerpt: chunk.content,
      ));
    }
    return citations;
  }

  @override
  void dispose() {
    _mounted = false;
    _streamSub?.cancel();
    super.dispose();
  }
}

final askLibraryChatProvider =
    StateNotifierProvider<AskLibraryChatNotifier, AskLibraryChatState>(
  AskLibraryChatNotifier.new,
);
```

- [ ] **Step 4: Run chat provider test**

Run: `flutter test test/providers/ask_library_chat_provider_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/providers/ask_library_chat_provider.dart test/providers/ask_library_chat_provider_test.dart
git commit -m "feat(rag): add ask library chat provider"
```

---

### Task 8: Add Ask Library Screen And Library Entry

**Files:**
- Create: `lib/screens/ask_library_screen.dart`
- Modify: `lib/screens/meeting_library_screen.dart`
- Test: `test/screens/ask_library_screen_test.dart`

- [ ] **Step 1: Write screen smoke test**

Create `test/screens/ask_library_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/screens/ask_library_screen.dart';

void main() {
  testWidgets('shows Ask Library title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AskLibraryScreen()),
      ),
    );

    expect(find.text('Ask Library'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run screen test and verify it fails**

Run: `flutter test test/screens/ask_library_screen_test.dart`

Expected: FAIL because `AskLibraryScreen` does not exist.

- [ ] **Step 3: Implement `AskLibraryScreen`**

Create `lib/screens/ask_library_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_rag.dart';
import '../providers/ask_library_chat_provider.dart';
import '../providers/library_rag_provider.dart';
import '../widgets/spring_page_route.dart';
import 'meeting_detail_screen.dart';

class AskLibraryScreen extends ConsumerStatefulWidget {
  const AskLibraryScreen({super.key});

  @override
  ConsumerState<AskLibraryScreen> createState() => _AskLibraryScreenState();
}

class _AskLibraryScreenState extends ConsumerState<AskLibraryScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(libraryRagSetupProvider);
    final chat = ref.watch(askLibraryChatProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Library')),
      body: switch (setup.readiness) {
        LibraryRagReadiness.disabled => _SetupView(
            text: 'Enable local library chat to index your transcripts and documents for contextual search.',
            buttonText: 'Enable',
            onPressed: () => ref.read(libraryRagSetupProvider.notifier).enableAndEstimate(),
          ),
        LibraryRagReadiness.enabledNotIndexed => _EstimateView(setup: setup),
        LibraryRagReadiness.indexing => _IndexingView(setup: setup),
        LibraryRagReadiness.failed => _SetupView(
            text: setup.error ?? 'Local library chat failed.',
            buttonText: 'Retry',
            onPressed: () => ref.read(libraryRagSetupProvider.notifier).loadEstimate(),
          ),
        LibraryRagReadiness.ready || LibraryRagReadiness.stale => _ChatView(
            chat: chat,
            controller: _controller,
            scrollController: _scrollController,
            onSend: _send,
            onCitationTap: _openCitation,
          ),
      },
    );
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    ref.read(askLibraryChatProvider.notifier).sendMessage(text);
  }

  void _openCitation(LibraryCitation citation) {
    Navigator.push<void>(
      context,
      SpringPageRoute(
        builder: (_) => MeetingDetailScreen(
          meetingId: citation.libraryItemId,
          initialTabIndex: citation.contentType == LibraryContentType.transcript ? 1 : 0,
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  const _SetupView({required this.text, required this.buttonText, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}

class _EstimateView extends ConsumerWidget {
  final LibraryRagSetupState setup;

  const _EstimateView({required this.setup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = setup.estimate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              estimate == null
                  ? 'Preparing index estimate...'
                  : 'Index ${estimate.meetingCount} meetings and ${estimate.documentCount} documents. Estimated chunks: ${estimate.estimatedChunks}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: estimate?.hasEligibleContent == true
                  ? () => ref.read(libraryRagSetupProvider.notifier).indexLibrary()
                  : null,
              child: const Text('Start indexing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexingView extends StatelessWidget {
  final LibraryRagSetupState setup;

  const _IndexingView({required this.setup});

  @override
  Widget build(BuildContext context) {
    final progress = setup.progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress?.fraction),
            const SizedBox(height: 16),
            Text(progress?.currentTitle ?? 'Indexing library...'),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  final AskLibraryChatState chat;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final ValueChanged<LibraryCitation> onCitationTap;

  const _ChatView({
    required this.chat,
    required this.controller,
    required this.scrollController,
    required this.onSend,
    required this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: chat.messages.length,
            itemBuilder: (context, index) {
              final message = chat.messages[index];
              return Align(
                alignment: message.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.content),
                        if (message.citations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: message.citations
                                .map(
                                  (citation) => ActionChip(
                                    label: Text(citation.title),
                                    onPressed: () => onCitationTap(citation),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (chat.error != null) Text(chat.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: controller, enabled: !chat.isStreaming)),
                IconButton(onPressed: chat.isStreaming ? null : onSend, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add library entry**

Modify `lib/screens/meeting_library_screen.dart` imports:

```dart
import 'ask_library_screen.dart';
```

Change `_buildList` to include an `Ask Library` tile before meetings:

```dart
  Widget _buildList(List<Meeting> meetings, AppLocalizations l10n) {
    if (meetings.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        children: const [_AskLibraryTile()],
      );
    }
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        itemCount: meetings.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return const _AskLibraryTile();
          final meeting = meetings[i - 1];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: animDuration(ctx, Duration(milliseconds: 400 + ((i - 1) * 50))),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: _MeetingTile(meeting: meeting),
          );
        },
      ),
    );
  }
```

Add the tile class before `_MeetingTile`:

```dart
class _AskLibraryTile extends StatelessWidget {
  const _AskLibraryTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ListTile(
        leading: const Icon(Icons.manage_search_outlined),
        title: const Text('Ask Library'),
        subtitle: const Text('Search and chat across indexed transcripts and documents'),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push<void>(context, SpringPageRoute(builder: (_) => const AskLibraryScreen()));
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run screen test**

Run: `flutter test test/screens/ask_library_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/screens/ask_library_screen.dart lib/screens/meeting_library_screen.dart test/screens/ask_library_screen_test.dart
git commit -m "feat(rag): add ask library screen"
```

---

### Task 9: Support Transcript-Tab Citation Navigation

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`
- Modify: `test/screens/meeting_detail_screen_test.dart`

- [ ] **Step 1: Add failing widget test for initial tab**

Append to `test/screens/meeting_detail_screen_test.dart`:

```dart
testWidgets('initialTabIndex opens transcript tab', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: MeetingDetailScreen(meetingId: 'test-id', initialTabIndex: 1),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  expect(tabBar.controller?.index, 1);
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/screens/meeting_detail_screen_test.dart --name "initialTabIndex opens transcript tab"`

Expected: FAIL because `initialTabIndex` does not exist.

- [ ] **Step 3: Add `initialTabIndex` to screen**

Modify `lib/screens/meeting_detail_screen.dart`:

```dart
class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final int initialTabIndex;

  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.initialTabIndex = 0,
  });
```

Change `initState()` controller initialization:

```dart
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
```

- [ ] **Step 4: Run meeting detail test**

Run: `flutter test test/screens/meeting_detail_screen_test.dart --name "initialTabIndex opens transcript tab"`

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/screens/meeting_detail_screen.dart test/screens/meeting_detail_screen_test.dart
git commit -m "feat(rag): support citation transcript navigation"
```

---

### Task 10: Add Settings Visibility And Localization Cleanup

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Test: `test/screens/ask_library_screen_test.dart`

- [ ] **Step 1: Add localized strings to ARB files**

Add these keys to `lib/l10n/app_en.arb`:

```json
"askLibraryTitle": "Ask Library",
"askLibrarySubtitle": "Search and chat across indexed transcripts and documents",
"localLibraryChatTitle": "Local library chat",
"localLibraryChatSubtitleEnabled": "Ask Library indexing is enabled",
"localLibraryChatSubtitleDisabled": "Ask Library indexing is disabled"
```

Add these keys to `lib/l10n/app_de.arb`:

```json
"askLibraryTitle": "Bibliothek fragen",
"askLibrarySubtitle": "Durchsuche indexierte Transkripte und Dokumente im Chat",
"localLibraryChatTitle": "Lokaler Bibliothekschat",
"localLibraryChatSubtitleEnabled": "Indexierung für Bibliothek fragen ist aktiviert",
"localLibraryChatSubtitleDisabled": "Indexierung für Bibliothek fragen ist deaktiviert"
```

- [ ] **Step 2: Regenerate localization classes**

Run: `flutter gen-l10n`

Expected: `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, and `lib/l10n/app_localizations_de.dart` include the new getters.

- [ ] **Step 3: Replace Ask Library hard-coded UI strings**

In `lib/screens/ask_library_screen.dart`, import localization:

```dart
import '../l10n/app_localizations.dart';
```

Change the AppBar title:

```dart
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.askLibraryTitle)),
```

In `lib/screens/meeting_library_screen.dart`, change `_AskLibraryTile` to read localizations:

```dart
class _AskLibraryTile extends StatelessWidget {
  const _AskLibraryTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ListTile(
        leading: const Icon(Icons.manage_search_outlined),
        title: Text(l10n.askLibraryTitle),
        subtitle: Text(l10n.askLibrarySubtitle),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push<void>(context, SpringPageRoute(builder: (_) => const AskLibraryScreen()));
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Add local library chat settings row**

In `lib/screens/settings_screen.dart`, add this row to the `AI & Models` section after the API connection row:

```dart
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SettingsRow(
                icon: Icons.manage_search_outlined,
                title: l10n.localLibraryChatTitle,
                subtitle: settings.localLibraryChatEnabled
                    ? l10n.localLibraryChatSubtitleEnabled
                    : l10n.localLibraryChatSubtitleDisabled,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setLocalLibraryChatEnabled(!settings.localLibraryChatEnabled);
                },
              ),
```

- [ ] **Step 5: Update Ask Library screen test localization wrapper**

Update `test/screens/ask_library_screen_test.dart` to import localization:

```dart
import 'package:summsumm/l10n/app_localizations.dart';
```

Replace the test app with:

```dart
await tester.pumpWidget(
  const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AskLibraryScreen(),
    ),
  ),
);
```

- [ ] **Step 6: Run analyzer on changed UI files**

Run: `flutter analyze`

Expected: no analyzer errors from the new settings row/localization changes.

- [ ] **Step 7: Run Ask Library screen test**

Run: `flutter test test/screens/ask_library_screen_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add lib/screens/settings_screen.dart lib/screens/ask_library_screen.dart lib/screens/meeting_library_screen.dart lib/l10n test/screens/ask_library_screen_test.dart
git commit -m "feat(rag): expose local library chat setting"
```

---

### Task 11: Generate Riverpod Files And Run Full Verification

**Files:**
- Generated: `lib/providers/settings_provider.g.dart` if build output changes
- Generated: localization files from `flutter gen-l10n`

- [ ] **Step 1: Run build runner**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: completes successfully.

- [ ] **Step 2: Run focused tests**

Run:

```bash
flutter test test/models/app_settings_test.dart test/models/library_rag_test.dart test/services/library_rag_metadata_store_test.dart test/services/library_rag_service_test.dart test/services/library_rag_repository_test.dart test/providers/library_rag_provider_test.dart test/providers/ask_library_chat_provider_test.dart test/screens/ask_library_screen_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run full tests**

Run: `flutter test`

Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`

Expected: no errors.

- [ ] **Step 5: Commit generated and verification fixes**

Run:

```bash
git add lib/providers/settings_provider.g.dart lib/l10n test lib
git commit -m "test(rag): verify ask library rag flow"
```

If `git status --short` shows no files from this task, do not create an empty commit.

---

## Manual QA Checklist

- [ ] Install/run the app on Android.
- [ ] Open the library and verify `Ask Library` appears above library items.
- [ ] Open `Ask Library` with the feature disabled and verify the setup copy is clear.
- [ ] Enable local library chat and verify the estimate appears before indexing.
- [ ] Confirm indexing and verify progress appears.
- [ ] Ask a question that should be answered by a meeting transcript.
- [ ] Verify the answer streams and shows at least one citation.
- [ ] Tap a meeting citation and verify the meeting detail opens on the Transcript tab.
- [ ] Ask a question with no relevant library context and verify the app says it could not find enough information.
- [ ] Import a PDF document, index/update, ask a question about it, and verify document citation navigation opens the document detail.

---

## Self-Review Notes

- Spec coverage: Tasks cover bundled assets, opt-in setting, estimate/confirmation, indexing, retrieval, AI chat, citations, transcript-tab navigation, settings visibility, tests, generated code, and verification.
- Deferred scope is preserved: no multilingual model download, no summary indexing, no source filters, no snippet scrolling/highlighting, no package fork.
- Type consistency: `LibraryRagReadiness`, `LibraryIndexEstimate`, `LibraryIndexProgress`, `IndexedLibrarySource`, `LibraryCitation`, `LibraryRagService`, `LibraryRagRepository`, `libraryRagSetupProvider`, and `askLibraryChatProvider` are introduced before use.

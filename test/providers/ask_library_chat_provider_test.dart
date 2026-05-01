import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/chat_session.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/ask_library_chat_provider.dart';
import 'package:summsumm/providers/chat_repository_provider.dart';
import 'package:summsumm/providers/library_rag_provider.dart';
import 'package:summsumm/providers/models_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/services/chat_repository.dart';
import 'package:summsumm/services/library_rag_metadata_store.dart';
import 'package:summsumm/services/library_rag_repository.dart';
import 'package:summsumm/services/library_rag_service.dart';

void main() {
  test('initial chat state is empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(askLibraryChatProvider);

    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);
  });

  test('new chat clears messages and errors', () {
    final container = ProviderContainer(
      overrides: [
        askLibraryChatProvider.overrideWith(
          (ref) => TestAskLibraryChatNotifier(
            ref,
            const AskLibraryChatState(
              messages: [AskLibraryMessage(role: 'user', content: 'Question')],
              isStreaming: true,
              error: 'Failed',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(askLibraryChatProvider.notifier);

    notifier.newChat();

    final state = container.read(askLibraryChatProvider);
    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);
  });

  test('follow-up turns include recent chat in the llm prompt', () async {
    final fakeRepository = _FakeLibraryRagRepository([
      _searchResult('First context', 'Budget Kickoff'),
      _searchResult('Second context', 'Budget Deep Dive'),
    ]);
    final fakeAiService = _FakeAiService(['First answer', 'Second answer']);
    final container = ProviderContainer(
      overrides: [
        libraryRagRepositoryProvider.overrideWithValue(fakeRepository),
        aiServiceProvider.overrideWithValue(fakeAiService),
        settingsProvider.overrideWith(_LoadedSettings.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(askLibraryChatProvider.notifier);

    await notifier.sendMessage('What happened in the budget meeting?');
    await _flushAsyncEvents();
    await notifier.sendMessage('Give more context on the second point.');
    await _flushAsyncEvents();

    final secondPrompt = fakeAiService.calls[1];
    final promptText = secondPrompt
        .map((message) => message['content'].toString())
        .join('\n');

    expect(promptText, contains('What happened in the budget meeting?'));
    expect(promptText, contains('First answer'));
    expect(promptText, contains('Give more context on the second point.'));
  });

  test('follow-up turns build retrieval queries from recent chat', () async {
    final fakeRepository = _FakeLibraryRagRepository([
      _searchResult('First context', 'Budget Kickoff'),
      _searchResult('Second context', 'Budget Deep Dive'),
    ]);
    final fakeAiService = _FakeAiService(['First answer', 'Second answer']);
    final container = ProviderContainer(
      overrides: [
        libraryRagRepositoryProvider.overrideWithValue(fakeRepository),
        aiServiceProvider.overrideWithValue(fakeAiService),
        settingsProvider.overrideWith(_LoadedSettings.new),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(askLibraryChatProvider.notifier);

    await notifier.sendMessage('What happened in the budget meeting?');
    await _flushAsyncEvents();
    await notifier.sendMessage('Give more context on the second point.');
    await _flushAsyncEvents();

    expect(fakeRepository.queries, hasLength(2));
    expect(
      fakeRepository.queries[1],
      contains('What happened in the budget meeting?'),
    );
    expect(fakeRepository.queries[1], contains('First answer'));
    expect(
      fakeRepository.queries[1],
      contains('Give more context on the second point.'),
    );
  });

  test(
    'follow-up assistant message uses only fresh retrieval citations',
    () async {
      final fakeRepository = _FakeLibraryRagRepository([
        _searchResult('First context', 'Budget Kickoff'),
        _searchResult('Second context', 'Budget Deep Dive'),
      ]);
      final fakeAiService = _FakeAiService(['First answer', 'Second answer']);
      final container = ProviderContainer(
        overrides: [
          libraryRagRepositoryProvider.overrideWithValue(fakeRepository),
          aiServiceProvider.overrideWithValue(fakeAiService),
          settingsProvider.overrideWith(_LoadedSettings.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(askLibraryChatProvider.notifier);

      await notifier.sendMessage('What happened in the budget meeting?');
      await _flushAsyncEvents();
      await notifier.sendMessage('Give more context on the second point.');
      await _flushAsyncEvents();

      final state = container.read(askLibraryChatProvider);
      expect(state.messages, hasLength(4));
      expect(state.messages[1].citations.single.title, 'Budget Kickoff');
      expect(state.messages[3].citations.single.title, 'Budget Deep Dive');
    },
  );

  test(
    'follow-up prompt and retrieval query drop history beyond limits',
    () async {
      final fakeRepository = _FakeLibraryRagRepository([
        _searchResult('Context 1', 'Source 1'),
        _searchResult('Context 2', 'Source 2'),
        _searchResult('Context 3', 'Source 3'),
        _searchResult('Context 4', 'Source 4'),
        _searchResult('Context 5', 'Source 5'),
      ]);
      final fakeAiService = _FakeAiService([
        'Answer 1',
        'Answer 2',
        'Answer 3',
        'Answer 4',
        'Answer 5',
      ]);
      final container = ProviderContainer(
        overrides: [
          libraryRagRepositoryProvider.overrideWithValue(fakeRepository),
          aiServiceProvider.overrideWithValue(fakeAiService),
          settingsProvider.overrideWith(_LoadedSettings.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(askLibraryChatProvider.notifier);

      await notifier.sendMessage('Question 1');
      await _flushAsyncEvents();
      await notifier.sendMessage('Question 2');
      await _flushAsyncEvents();
      await notifier.sendMessage('Question 3');
      await _flushAsyncEvents();
      await notifier.sendMessage('Question 4');
      await _flushAsyncEvents();
      await notifier.sendMessage('Question 5');
      await _flushAsyncEvents();

      final latestPrompt = fakeAiService.calls.last
          .map((message) => message['content'].toString())
          .join('\n');
      final latestQuery = fakeRepository.queries.last;

      expect(latestPrompt, isNot(contains('Question 1')));
      expect(latestPrompt, contains('Question 2'));
      expect(latestPrompt, contains('Answer 2'));
      expect(latestPrompt, contains('Question 5'));

      expect(latestQuery, isNot(contains('Question 2')));
      expect(latestQuery, contains('Question 3'));
      expect(latestQuery, contains('Answer 3'));
      expect(latestQuery, contains('Question 5'));
    },
  );

  test('saved chat titles use the first question without a prefix', () async {
    final fakeRepository = _FakeLibraryRagRepository([
      _searchResult('Context', 'Budget Meeting'),
    ]);
    final fakeAiService = _FakeAiService(['Answer']);
    final fakeChatRepository = _FakeChatRepository();
    final container = ProviderContainer(
      overrides: [
        libraryRagRepositoryProvider.overrideWithValue(fakeRepository),
        aiServiceProvider.overrideWithValue(fakeAiService),
        settingsProvider.overrideWith(_LoadedSettings.new),
        chatRepositoryProvider.overrideWithValue(fakeChatRepository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(askLibraryChatProvider.notifier)
        .sendMessage('What happened in the budget meeting?');
    await _flushAsyncEvents();

    expect(
      fakeChatRepository.saved.single.title,
      'What happened in the budget meeting?',
    );
  });
}

Future<void> _flushAsyncEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

LibraryRagSearchResult _searchResult(String contextText, String title) {
  return LibraryRagSearchResult(
    contextText: contextText,
    chunks: [
      LibraryRagSearchChunk(
        sourceId: 1,
        content: contextText,
        metadata:
            '{"libraryItemId":"meeting-1","title":"$title","sourceKind":"meeting","contentType":"transcript"}',
      ),
    ],
  );
}

class TestAskLibraryChatNotifier extends AskLibraryChatNotifier {
  TestAskLibraryChatNotifier(super.ref, AskLibraryChatState initialState) {
    state = initialState;
  }
}

class _LoadedSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults().copyWith(
    provider: 'openai',
    openaiModel: 'gpt-5.4-mini',
    localLibraryChatEnabled: true,
  );

  @override
  Future<void> load() async {}

  @override
  Future<String?> getApiKey(String provider) async => 'test-key';
}

class _FakeAiService extends AiService {
  _FakeAiService(this._responses);

  final List<String> _responses;
  final List<List<Map<String, dynamic>>> calls = [];
  var _index = 0;

  @override
  Stream<String> streamCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required String provider,
  }) async* {
    calls.add(messages);
    yield _responses[_index++];
  }
}

class _FakeLibraryRagRepository extends LibraryRagRepository {
  _FakeLibraryRagRepository(this._results)
    : super(
        ragService: LibraryRagService(client: FakeLibraryRagClient()),
        metadataStore: _MemoryMetadataStore(),
        documentTextExtractor: (_) async => '',
      );

  final List<LibraryRagSearchResult> _results;
  final List<String> queries = [];
  var _index = 0;

  @override
  Future<LibraryRagSearchResult> search(String query) async {
    queries.add(query);
    return _results[_index++];
  }
}

class _MemoryMetadataStore extends LibraryRagMetadataStore {
  _MemoryMetadataStore();

  LibraryRagMetadata _metadata = const LibraryRagMetadata();

  @override
  Future<LibraryRagMetadata> load() async => _metadata;

  @override
  Future<void> save(LibraryRagMetadata metadata) async {
    _metadata = metadata;
  }
}

class _FakeChatRepository extends ChatRepository {
  final List<ChatSession> saved = [];

  @override
  Future<void> save(ChatSession session) async {
    saved.add(session);
  }
}

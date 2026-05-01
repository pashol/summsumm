import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/library_rag_provider.dart';
import 'package:summsumm/providers/local_llm_provider.dart';
import 'package:summsumm/providers/meeting_chat_provider.dart';
import 'package:summsumm/providers/meeting_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/services/library_rag_metadata_store.dart';
import 'package:summsumm/services/library_rag_service.dart';
import 'package:summsumm/services/local_llm_service.dart';

void main() {
  test('initial state has empty messages and is not streaming', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(meetingChatProvider('test-id'));
    expect(state.messages, isEmpty);
    expect(state.isStreaming, false);
    expect(state.error, isNull);
  });

  test('different meetingIds get independent state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final aNotifier = container.read(meetingChatProvider('a').notifier);
    final bNotifier = container.read(meetingChatProvider('b').notifier);
    expect(aNotifier, isNot(same(bNotifier)));
  });

  test('RAG fallback when meeting not indexed uses cloud path', () async {
    final fakeAiService = _FakeAiService(['Cloud answer']);
    final fakeMetadataStore = _FakeLibraryRagMetadataStore();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_LoadedSettings.new),
        aiServiceProvider.overrideWithValue(fakeAiService),
        libraryRagMetadataStoreProvider.overrideWithValue(fakeMetadataStore),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(meetingChatProvider('meeting-1').notifier);

    await notifier.sendMessage(
      'What was discussed?',
      transcript: 'Test transcript',
      meetingId: 'meeting-1',
    );
    await _flushAsyncEvents();

    expect(fakeAiService.calls, hasLength(1));
    final prompt = fakeAiService.calls.first
        .map((message) => message['content'].toString())
        .join('\n');
    expect(prompt, contains('Test transcript'));
    expect(prompt, contains('Answer questions about this meeting concisely'));

    final state = container.read(meetingChatProvider('meeting-1'));
    expect(state.isStreaming, isFalse);
    expect(state.messages.last.content, 'Cloud answer');
  });

  test('local AI routing uses local stream when enabled', () async {
    final fakeLocalLlm = _FakeLocalLlmService(['Local answer']);
    final fakeMetadataStore = _FakeLibraryRagMetadataStore();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_LocalAiSettings.new),
        localLlmServiceProvider.overrideWithValue(fakeLocalLlm),
        libraryRagMetadataStoreProvider.overrideWithValue(fakeMetadataStore),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(meetingChatProvider('meeting-1').notifier);

    await notifier.sendMessage(
      'What was discussed?',
      transcript: 'Test transcript',
      meetingId: 'meeting-1',
    );
    await _flushAsyncEvents();

    expect(fakeLocalLlm.streamChatCalls, hasLength(1));
    final state = container.read(meetingChatProvider('meeting-1'));
    expect(state.messages.last.content, 'Local answer');
    expect(state.isStreaming, isFalse);
  });
}

Future<void> _flushAsyncEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _LoadedSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults().copyWith(
    provider: 'openai',
    openaiModel: 'gpt-5.4-mini',
  );

  @override
  Future<void> load() async {}

  @override
  Future<String?> getApiKey(String provider) async => 'test-key';
}

class _LocalAiSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults().copyWith(
    provider: 'openai',
    openaiModel: 'gpt-5.4-mini',
    localAiEnabled: true,
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

class _FakeLibraryRagMetadataStore extends LibraryRagMetadataStore {
  @override
  Future<LibraryRagMetadata> load() async => const LibraryRagMetadata();
}

class _FakeLocalLlmService extends LocalLlmService {
  final List<String> _responses;
  final List<Map<String, dynamic>> streamChatCalls = [];
  var _index = 0;

  _FakeLocalLlmService(this._responses);

  @override
  Future<bool> isModelInstalled() async => true;

  @override
  Future<void> ensureModelLoaded() async {}

  @override
  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async* {
    streamChatCalls.add({
      'systemPrompt': systemPrompt,
      'messages': messages,
    });
    yield _responses[_index++];
  }
}

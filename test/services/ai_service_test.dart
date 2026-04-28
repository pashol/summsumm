import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:summsumm/services/ai_service.dart';

class _MockClient extends http.BaseClient {
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  final Completer<http.StreamedResponse> _completer =
      Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return _completer.future;
  }

  void emit(String text) {
    _controller.add(utf8.encode(text));
  }

  void complete({int statusCode = 200}) {
    _completer.complete(
      http.StreamedResponse(
        _controller.stream,
        statusCode,
      ),
    );
  }
}

class _TestableAiService extends AiService {
  final http.Client _client;
  List<Map<String, dynamic>>? lastMessages;

  _TestableAiService(this._client);

  @override
  Stream<String> streamCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required String provider,
  }) async* {
    lastMessages = messages;
    final isProviderOpenAi = provider == 'openai';
    final endpoint = isProviderOpenAi
        ? 'https://api.openai.com/v1/chat/completions'
        : 'https://openrouter.ai/api/v1/chat/completions';
    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (!isProviderOpenAi) ...{
        'HTTP-Referer': 'https://github.com/pashol/summsumm',
        'X-Title': 'AI Text Summarizer',
      },
    });
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'max_tokens': 4096,
    });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Request failed');
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final delta = (json['choices'] as List?)?.first?['delta']?['content'];
          if (delta is String && delta.isNotEmpty) yield delta;
        } catch (_) {}
      }
    }
  }
}

void main() {
  group('AiService', () {
    test('cleanupTranscript streams cleaned text', () async {
      final mockClient = _MockClient();
      final service = _TestableAiService(mockClient);
      const raw = 'Um, like, this is a test. Uh, yeah.';

      final futureChunks = service
          .cleanupTranscript(
            rawTranscript: raw,
            provider: 'openai',
            apiKey: 'test-key',
            model: 'gpt-5.4-nano',
          )
          .toList();

      mockClient
          .emit('data: {"choices":[{"delta":{"content":"Cleaned"}}]}\n\n');
      mockClient.emit('data: {"choices":[{"delta":{"content":" text"}}]}\n\n');
      mockClient.emit('data: [DONE]\n\n');
      mockClient.complete();

      final chunks = await futureChunks;
      expect(chunks.join(), 'Cleaned text');
    });

    test('cleanupTranscript tells models not to add meta text', () async {
      final mockClient = _MockClient();
      final service = _TestableAiService(mockClient);

      final futureChunks = service
          .cleanupTranscript(
            rawTranscript: 'Hello there.',
            provider: 'openai',
            apiKey: 'test-key',
            model: 'gpt-5.4-nano',
          )
          .toList();

      mockClient.emit('data: [DONE]\n\n');
      mockClient.complete();
      await futureChunks;

      final prompt = service.lastMessages!.single['content'] as String;
      expect(prompt, contains('Do not add an introduction.'));
      expect(prompt, contains('Do not add explanations.'));
      expect(prompt, contains('Do not add a "Changes made" section.'));
      expect(prompt, contains('Output only the cleaned transcript.'));
    });

    test('cleanupTranscript uses plain transcript rules when not diarized',
        () async {
      final mockClient = _MockClient();
      final service = _TestableAiService(mockClient);

      final futureChunks = service
          .cleanupTranscript(
            rawTranscript: 'Hello there.',
            provider: 'openai',
            apiKey: 'test-key',
            model: 'gpt-5.4-nano',
          )
          .toList();

      mockClient.emit('data: [DONE]\n\n');
      mockClient.complete();
      await futureChunks;

      final prompt = service.lastMessages!.single['content'] as String;
      expect(prompt, contains('Do not add timestamps.'));
      expect(prompt, contains('Do not add speaker labels.'));
      expect(prompt, isNot(contains('Keep timestamps and speaker labels')));
    });

    test('cleanupTranscript preserves labels and timestamps when diarized',
        () async {
      final mockClient = _MockClient();
      final service = _TestableAiService(mockClient);

      final futureChunks = service
          .cleanupTranscript(
            rawTranscript: '[00:00] Speaker 1: Hello there.',
            provider: 'openai',
            apiKey: 'test-key',
            model: 'gpt-5.4-nano',
            diarized: true,
          )
          .toList();

      mockClient.emit('data: [DONE]\n\n');
      mockClient.complete();
      await futureChunks;

      final prompt = service.lastMessages!.single['content'] as String;
      expect(prompt,
          contains('Keep timestamps and speaker labels exactly as they are'));
      expect(prompt, isNot(contains('Do not add timestamps.')));
      expect(prompt, isNot(contains('Do not add speaker labels.')));
    });
  });
}

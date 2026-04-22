import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:summsumm/services/ai_service.dart';

class _MockClient extends http.BaseClient {
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  final Completer<http.StreamedResponse> _completer = Completer<http.StreamedResponse>();

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

  _TestableAiService(this._client);

  @override
  Stream<String> streamCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required String provider,
  }) async* {
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
      final raw = 'Um, like, this is a test. Uh, yeah.';

      final futureChunks = service.cleanupTranscript(
        rawTranscript: raw,
        provider: 'openai',
        apiKey: 'test-key',
        model: 'gpt-5.4-nano',
      ).toList();

      mockClient.emit('data: {"choices":[{"delta":{"content":"Cleaned"}}]}\n\n');
      mockClient.emit('data: {"choices":[{"delta":{"content":" text"}}]}\n\n');
      mockClient.emit('data: [DONE]\n\n');
      mockClient.complete();

      final chunks = await futureChunks;
      expect(chunks.join(), 'Cleaned text');
    });
  });
}

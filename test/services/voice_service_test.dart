import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:summsumm/services/voice_service.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => Directory.systemTemp.path;
}

void main() {
  group('VoiceService recording defaults', () {
    test('uses mp3 container for microphone capture', () {
      final service = VoiceService();
      expect(service.recordingFileExtension, 'mp3');
      expect(service.recordingCodec, Codec.mp3);
    });
  });

  group('transcribeWithGemini', () {
    late File audioFile;

    setUp(() async {
      PathProviderPlatform.instance = FakePathProvider();
      audioFile = File('${Directory.systemTemp.path}/test_audio.mp3');
      await audioFile.writeAsBytes([0x00, 0x01, 0x02]);
    });

    tearDown(() async {
      if (await audioFile.exists()) await audioFile.delete();
    });

    test('sends request to OpenRouter with correct model and diarization prompt', () async {
      late http.Request capturedRequest;

      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '[00:01] Speaker 1: Hello world.',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = VoiceService(httpClient: client);
      final result = await service.transcribeWithGemini(audioFile.path, 'test-key');

      expect(capturedRequest.url.host, 'openrouter.ai');
      expect(capturedRequest.headers['Authorization'], 'Bearer test-key');
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['model'], 'google/gemini-flash-3');
      final messages = body['messages'] as List;
      final content = messages.first['content'] as List;
      final textBlock = content.firstWhere((c) => c['type'] == 'text');
      expect(textBlock['text'], contains('Speaker'));
      expect(textBlock['text'], contains('[MM:SS]'));
      expect(result, '[00:01] Speaker 1: Hello world.');
    });

    test('throws VoiceTranscriptionException on non-200 response', () async {
      final client = MockClient((_) async => http.Response('{"error":"bad key"}', 401));
      final service = VoiceService(httpClient: client);

      expect(
        () => service.transcribeWithGemini(audioFile.path, 'bad-key'),
        throwsA(isA<VoiceTranscriptionException>()),
      );
    });

    test('throws VoiceTranscriptionException if audio file missing', () async {
      final service = VoiceService();
      expect(
        () => service.transcribeWithGemini('/nonexistent/path.mp3', 'key'),
        throwsA(isA<VoiceTranscriptionException>()),
      );
    });
  });

  group('transcribeFile routing', () {
    late File audioFile;

    setUp(() async {
      audioFile = File('${Directory.systemTemp.path}/test_route.mp3');
      await audioFile.writeAsBytes([0x00, 0x01]);
    });

    tearDown(() async {
      if (await audioFile.exists()) await audioFile.delete();
    });

    test('routes to Gemini when diarize=true and provider=openrouter', () async {
      String? capturedModel;

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedModel = body['model'] as String?;
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': '[00:00] Speaker 1: Hi.'}},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = VoiceService(httpClient: client);
      await service.transcribeFile(audioFile.path, 'openrouter', 'key', diarize: true);

      expect(capturedModel, 'google/gemini-flash-3');
    });

    test('routes to Voxtral when diarize=false and provider=openrouter', () async {
      String? capturedModel;

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedModel = body['model'] as String?;
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': 'plain transcript'}},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = VoiceService(httpClient: client);
      await service.transcribeFile(audioFile.path, 'openrouter', 'key', diarize: false);

      expect(capturedModel, 'mistralai/voxtral-small-24b-2507');
    });
  });
}

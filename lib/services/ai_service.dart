import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

import '../models/ai_model.dart';
import 'voice_service.dart';

const _openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
const _openRouterModelsEndpoint = 'https://openrouter.ai/api/v1/models';
const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
const _connectTimeout = Duration(seconds: 30);
const _streamIdleTimeout = Duration(seconds: 60);
const _maxRetries = 2;

const _openRouterAppUrl = 'https://github.com/pashol/summsumm';
const _openRouterAppTitle = 'AI Text Summarizer';

Map<String, String> _openRouterAttributionHeaders() => const {
      'HTTP-Referer': _openRouterAppUrl,
      'X-Title': _openRouterAppTitle,
    };

class AiService {
  final VoiceService _voiceService = VoiceService();

  Stream<String> streamCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required String provider,
  }) async* {
    final isProviderOpenAi = provider == 'openai';
    final endpoint = isProviderOpenAi ? _openAiEndpoint : _openRouterEndpoint;
    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (!isProviderOpenAi) ..._openRouterAttributionHeaders(),
    });
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
    });

    final http.Client client = http.Client();
    try {
      final response = await client.send(request).timeout(_connectTimeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw AiException(parseError(response.statusCode, body));
      }

      String buffer = '';
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(_streamIdleTimeout)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;
          if (!trimmedLine.startsWith('data:')) continue;
          final data = trimmedLine.substring(5).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta =
                (json['choices'] as List?)?.first?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) yield delta;
          } catch (_) {
            // Malformed SSE line — skip
          }
        }
      }
      // Process any remaining buffer content
      if (buffer.trim().isNotEmpty) {
        final trimmedLine = buffer.trim();
        if (trimmedLine.startsWith('data:')) {
          final data = trimmedLine.substring(5).trim();
          if (data != '[DONE]') {
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final delta =
                  (json['choices'] as List?)?.first?['delta']?['content'];
              if (delta is String && delta.isNotEmpty) yield delta;
            } catch (_) {}
          }
        }
      }
    } on TimeoutException {
      throw const AiException('Connection timed out. Please try again.');
    } finally {
      client.close();
    }
  }

  Stream<String> streamCompletionWithFile({
    required String apiKey,
    required String model,
    required io.File file,
    required String prompt,
    required String provider,
    String? systemPrompt,
  }) async* {
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    final isProviderOpenAi = provider == 'openai';
    final endpoint = isProviderOpenAi ? _openAiEndpoint : _openRouterEndpoint;

    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (!isProviderOpenAi) ..._openRouterAttributionHeaders(),
    });

    final userContent = [
      {
        'type': 'file',
        'file': {
          'filename': 'document.pdf',
          'file_data': 'data:application/pdf;base64,$base64Data',
        },
      },
      {
        'type': 'text',
        'text': prompt,
      },
    ];

    final effectiveSystemPrompt = systemPrompt ?? _pdfSystemPrompt;
    request.body = isProviderOpenAi
        ? jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': effectiveSystemPrompt},
              {'role': 'user', 'content': userContent},
            ],
            'stream': true,
          })
        : jsonEncode({
            'models': _pdfModelChain,
            'provider': {
              'sort': 'price',
              'allow_fallbacks': true,
            },
            'messages': [
              {'role': 'system', 'content': effectiveSystemPrompt},
              {'role': 'user', 'content': userContent},
            ],
            'stream': true,
          });

    final http.Client client = http.Client();
    try {
      final response = await client.send(request).timeout(_connectTimeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw AiException(parseError(response.statusCode, body));
      }

      String buffer = '';
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(_streamIdleTimeout)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;
          if (!trimmedLine.startsWith('data:')) continue;
          final data = trimmedLine.substring(5).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta =
                (json['choices'] as List?)?.first?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) yield delta;
          } catch (_) {}
        }
      }
    } on TimeoutException {
      throw const AiException('Connection timed out. Please try again.');
    } finally {
      client.close();
    }
  }

  // Fallback chain: Gemini first (native PDF + cheapest), Haiku as backup.
  // Both support native PDF processing via OpenRouter.
  static const _pdfModelChain = [
    'google/gemini-3-flash-preview',
    'anthropic/claude-haiku-4.5',
  ];

  static const _pdfSystemPrompt = '''
You are a helpful assistant that summarizes documents concisely. Formatting rules:
- Use ## for section headings, ### for sub-headings
- Use **bold** for key terms and important findings
- Use bullet lists for enumerations; numbered lists for sequential steps
- Do NOT use tables, HTML, or color markup
- Equations: write inline as plain text (e.g. E = mc^2)
- Scanned text: flag uncertain OCR with [UNVERIFIED]
- If a page contains only images/scans, note [SCANNED PAGE]
- Multi-page docs: brief structure overview first, then key sections
- Be concise but thorough: capture key points, not every detail
''';

  Future<String?> transcribeAudio({
    required String filePath,
    required String provider,
    required String apiKey,
  }) async {
    switch (provider) {
      case 'openai':
        return await _voiceService.transcribeWithOpenAI(filePath, apiKey);
      case 'openrouter':
        return await _voiceService.transcribeWithVoxtral(filePath, apiKey);
      default:
        return await _voiceService.transcribeLocally(filePath);
    }
  }

  Future<List<AIModel>> fetchOpenRouterModels(String apiKey) async {
    AiException? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(_openRouterModelsEndpoint),
          headers: {'Authorization': 'Bearer $apiKey'},
        ).timeout(_connectTimeout);
        if (response.statusCode != 200) {
          throw AiException(parseError(response.statusCode, response.body));
        }
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List? ?? [];
        final allModels = data
            .whereType<Map<String, dynamic>>()
            .map(AIModel.fromOpenRouterJson)
            .toList();

        // Filter: only text-capable models with sufficient context
        final filtered = allModels.where((m) {
          // Must have a reasonable context window for summarization
          if (m.contextLength > 0 && m.contextLength < 4096) return false;
          // Exclude vision-only / image-gen / audio-only models by id patterns
          final id = m.id.toLowerCase();
          if (id.contains('dall-e')) return false;
          if (id.contains('stable-diffusion')) return false;
          if (id.contains('midjourney')) return false;
          if (id.contains('flux')) return false;
          if (id.contains('sd3')) return false;
          if (id.contains('playai')) return false;
          if (id.contains('tts')) return false;
          if (id.contains('whisper')) return false;
          if (id.contains('wiz-perceptor')) return false;
          if (id.contains('perceptor')) return false;
          return true;
        }).toList();

        // Sort: free first (alphabetical), then paid (by price ascending)
        final free = filtered.where((m) => m.isFree).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final paid = filtered.where((m) => !m.isFree).toList()
          ..sort((a, b) {
            final aPrice =
                double.tryParse(a.pricingPrompt ?? '') ?? double.maxFinite;
            final bPrice =
                double.tryParse(b.pricingPrompt ?? '') ?? double.maxFinite;
            final priceCmp = aPrice.compareTo(bPrice);
            if (priceCmp != 0) return priceCmp;
            return a.name.compareTo(b.name);
          });
        return [...free, ...paid];
      } on AiException {
        rethrow;
      } on TimeoutException {
        lastError =
            const AiException('Connection timed out. Please try again.');
      } catch (e) {
        lastError = AiException(e.toString());
      }
    }
    throw lastError ?? const AiException('Failed to fetch models.');
  }

  Future<void> testConnection({
    required String apiKey,
    required String model,
    required String provider,
  }) async {
    final isProviderOpenAi = provider == 'openai';
    final endpoint = isProviderOpenAi ? _openAiEndpoint : _openRouterEndpoint;
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              if (!isProviderOpenAi) ..._openRouterAttributionHeaders(),
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'Hi'},
              ],
              'max_tokens': 1,
            }),
          )
          .timeout(_connectTimeout);
      if (response.statusCode != 200) {
        throw AiException(parseError(response.statusCode, response.body));
      }
    } on TimeoutException {
      throw const AiException('Connection timed out. Please try again.');
    }
  }

  String parseError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = json['error']?['message'] as String?;
      if (msg != null) return msg;
    } catch (_) {}
    switch (statusCode) {
      case 401:
        return 'Invalid API key (401)';
      case 403:
        return 'Access denied (403)';
      case 429:
        return 'Rate limit exceeded (429)';
      case 500:
        return 'Server error (500)';
      default:
        return 'Request failed ($statusCode)';
    }
  }
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

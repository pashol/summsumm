import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VoiceTranscriptionException implements Exception {
  final String message;
  final int? chunkIndex;

  VoiceTranscriptionException(this.message, [this.chunkIndex]);
  
  @override
  String toString() => chunkIndex != null
      ? '$message (chunk $chunkIndex)'
      : message;
}

class VoiceService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final http.Client _http;
  bool _isRecording = false;
  bool _isInitialized = false;
  Future<void>? _initializing;
  String? _tempFilePath;

  VoiceService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  String get recordingFileExtension => 'mp3';
  Codec get recordingCodec => Codec.mp3;

  bool get isRecording => _isRecording;

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }

    final initFuture = _initializeInternal();
    _initializing = initFuture;

    try {
      await initFuture;
      _isInitialized = true;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initializeInternal() async {
    await _recorder.openRecorder();
    await _speech.initialize();
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _recorder.closeRecorder();
    }
    _isInitialized = false;
    _initializing = null;
  }

  Future<String?> startRecording() async {
    if (_isRecording) return null;
    await init();
    _isRecording = true;

    final tempDir = await getTemporaryDirectory();
    _tempFilePath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$recordingFileExtension';

    await _recorder.startRecorder(
      toFile: _tempFilePath,
      codec: recordingCodec,
    );

    return _tempFilePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    await _recorder.stopRecorder();
    return _tempFilePath;
  }

  Future<String?> transcribeWithOpenAI(String filePath, String apiKey) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw VoiceTranscriptionException('Audio file missing.');
    }

    final bytes = await file.readAsBytes();
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
    final audioSubtype = switch (ext) {
      'm4a' => 'mp4',
      'aac' => 'aac',
      'ogg' || 'opus' => 'ogg',
      'wav' => 'wav',
      'flac' => 'flac',
      'mp3' => 'mpeg',
      'webm' => 'webm',
      _ => 'ogg',
    };
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: path.basename(filePath),
        contentType: MediaType('audio', audioSubtype),
      ),
    );
    request.fields['model'] = 'whisper-1';

    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['text'] as String?;
    }
    throw VoiceTranscriptionException(
      _formatError('OpenAI', response.statusCode, response.body),
    );
  }

  Future<String?> transcribeWithVoxtral(String filePath, String apiKey) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw VoiceTranscriptionException('Audio file missing.');
    }

    final bytes = await file.readAsBytes();
    final audioB64 = base64Encode(bytes);
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
    final audioFormat = switch (ext) {
      'm4a' => 'm4a',
      'aac' => 'm4a',
      'wav' => 'wav',
      'flac' => 'flac',
      'mp3' => 'mp3',
      'webm' => 'webm',
      _ => 'ogg',
    };

    final response = await _http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/pashol/summsumm',
        'X-Title': 'AI Text Summarizer',
      },
      body: jsonEncode({
        'model': 'mistralai/voxtral-small-24b-2507',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'data': audioB64, 'format': audioFormat},
              },
              {
                'type': 'text',
                'text':
                    'Transcribe the audio verbatim. Return only the transcription text, no commentary.',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content is String) return content.trim();
      if (content is List) {
        final text = content
            .whereType<Map<String, dynamic>>()
            .map((p) => p['text']?.toString() ?? '')
            .join()
            .trim();
        return text.isEmpty ? null : text;
      }
      return null;
    }
    throw VoiceTranscriptionException(
      _formatError('OpenRouter', response.statusCode, response.body),
    );
  }

  static const _geminiDiarizationModel = 'google/gemini-flash-3';

  static const _diarizationPrompt =
      'Transcribe this audio in full. Label each speaker as Speaker 1, Speaker 2, etc. '
      'If a word is unclear, write [inaudible] or your best guess in brackets like [unclear word?]. '
      'Format each line as:\n\n[MM:SS] Speaker X: <text>\n\n'
      'Maintain consistent speaker labels throughout. Do not summarize.';

  Future<String?> transcribeWithGemini(String filePath, String apiKey) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw VoiceTranscriptionException('Audio file missing.');
    }

    final bytes = await file.readAsBytes();
    final audioB64 = base64Encode(bytes);
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
    final audioFormat = switch (ext) {
      'm4a' => 'm4a',
      'aac' => 'm4a',
      'wav' => 'wav',
      'flac' => 'flac',
      'mp3' => 'mp3',
      'webm' => 'webm',
      _ => 'ogg',
    };

    final response = await _http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/pashol/summsumm',
        'X-Title': 'AI Text Summarizer',
      },
      body: jsonEncode({
        'model': _geminiDiarizationModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'data': audioB64, 'format': audioFormat},
              },
              {
                'type': 'text',
                'text': _diarizationPrompt,
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content is String) return content.trim();
      if (content is List) {
        final text = content
            .whereType<Map<String, dynamic>>()
            .map((p) => p['text']?.toString() ?? '')
            .join()
            .trim();
        return text.isEmpty ? null : text;
      }
      return null;
    }
    throw VoiceTranscriptionException(
      _formatError('OpenRouter/Gemini', response.statusCode, response.body),
    );
  }

  Future<List<String>> splitAudio(String filePath, {Duration chunkLength = const Duration(minutes: 8)}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw VoiceTranscriptionException('Audio file missing.');
    }

    // TODO: Implement actual audio splitting logic using FlutterSoundHelper
    return [filePath]; // Placeholder: return original file for now
  }

  Future<String?> transcribeFile(
    String filePath,
    String provider,
    String apiKey, {
    bool diarize = false,
  }) async {
    final chunks = await splitAudio(filePath);
    final transcriptParts = <String>[];

    for (var i = 0; i < chunks.length; i++) {
      try {
        final String? transcript;
        if (diarize && provider == 'openrouter') {
          transcript = await transcribeWithGemini(chunks[i], apiKey);
        } else if (provider == 'openai') {
          transcript = await transcribeWithOpenAI(chunks[i], apiKey);
        } else {
          transcript = await transcribeWithVoxtral(chunks[i], apiKey);
        }
        if (transcript != null) {
          transcriptParts.add(transcript);
        }
      } catch (e) {
        throw VoiceTranscriptionException(e.toString(), i);
      }
    }

    return transcriptParts.join('\n\n');
  }

  Future<String?> transcribeLocally(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/voice_temp.wav');
    await tempFile.writeAsBytes(bytes);

    var recognizedText = '';
    final isAvailable = await _speech.initialize();
    if (!isAvailable) return null;

    await _speech.listen(
      onResult: (result) => recognizedText = result.recognizedWords,
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      partialResults: false,
      localeId: 'en_US',
    );

    return recognizedText.isEmpty ? null : recognizedText;
  }

  String _formatError(String provider, int status, String body) {
    final snippet = body.length > 300 ? '${body.substring(0, 300)}…' : body;
    return '$provider transcription failed ($status): $snippet';
  }
}

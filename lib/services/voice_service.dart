import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum LogLevel { debug, info, warning, error }

class TranscriptionLogger {
  final String meetingId;
  final StringBuffer _logs = StringBuffer();
  final void Function(String status, double? progress)? onProgress;

  TranscriptionLogger(this.meetingId, {this.onProgress});

  void log(LogLevel level, String message, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] [${level.name.toUpperCase()}] $message${data != null ? ' ${data.toString()}' : ''}';
    _logs.writeln(entry);
    debugPrint(entry);
  }

  void info(String message, {Map<String, dynamic>? data}) => log(LogLevel.info, message, data: data);
  void debug(String message, {Map<String, dynamic>? data}) => log(LogLevel.debug, message, data: data);
  void warning(String message, {Map<String, dynamic>? data}) => log(LogLevel.warning, message, data: data);
  void error(String message, {Map<String, dynamic>? data}) => log(LogLevel.error, message, data: data);

  void progress(String status, double? progress) {
    onProgress?.call(status, progress);
    info(status);
  }

  String get fullLog => _logs.toString();
}

class VoiceTranscriptionException implements Exception {
  final String message;
  final int? chunkIndex;
  final String? log;

  VoiceTranscriptionException(this.message, [this.chunkIndex, this.log]);

  @override
  String toString() {
    var result = 'VoiceTranscriptionException: $message';
    if (chunkIndex != null) result += ' (chunk $chunkIndex)';
    if (log != null) result += '\n--- Transcription log ---\n$log';
    return result;
  }
}

typedef ProgressCallback = void Function(String status, double? progress);

class VoiceService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final http.Client _http;
  bool _isRecording = false;
  bool _isInitialized = false;
  Future<void>? _initializing;
  String? _tempFilePath;
  bool _debugMode = false;

  VoiceService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  String get recordingFileExtension => 'm4a';
  Codec get recordingCodec => Codec.aacMP4;

  bool get isRecording => _isRecording;

  void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

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
    try {
      await _recorder.openRecorder();
    } catch (e) {
      throw VoiceTranscriptionException('Failed to open recorder: $e');
    }
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
      sampleRate: 16000,
      bitRate: 64000,
      numChannels: 1,
    );

    return _tempFilePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    await _recorder.stopRecorder();
    return _tempFilePath;
  }

  // --- FFmpeg static helpers (can run in isolate) ---

  Future<String> _preprocessAudio(String inputPath, String outputPath) async {
    final completer = Completer<String>();
    final cmd = '-y -i "$inputPath" -vn -ac 1 -ar 16000 '
        '-af "highpass=f=80,lowpass=f=7600,loudnorm=I=-16:TP=-1.5:LRA=11" '
        '-c:a aac -b:a 64k "$outputPath"';
    await FFmpegKit.executeAsync(cmd, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        completer.complete(outputPath);
      } else {
        final logs = await session.getAllLogsAsString();
        completer.completeError(VoiceTranscriptionException('Preprocessing failed: $logs'));
      }
    });
    return completer.future;
  }

  Future<List<Map<String, double>>> _detectSilence(String inputPath) async {
    final logs = StringBuffer();

    await FFmpegKit.executeAsync(
      '-i "$inputPath" -af "silencedetect=noise=-32dB:d=0.7" -f null -',
      (session) {},
      (log) {
        logs.writeln(log.getMessage());
      },
      (stats) {},
    );

    final silenceStarts = <double>[];
    final silenceEnds = <double>[];

    for (final line in logs.toString().split('\n')) {
      final startMatch = RegExp(r'silence_start:\s+([0-9.]+)').firstMatch(line);
      if (startMatch != null) {
        silenceStarts.add(double.parse(startMatch.group(1)!));
      }
      final endMatch = RegExp(r'silence_end:\s+([0-9.]+)\s').firstMatch(line);
      if (endMatch != null) {
        silenceEnds.add(double.parse(endMatch.group(1)!));
      }
    }

    final segments = <Map<String, double>>[];
    double lastEnd = 0.0;
    for (int i = 0; i < silenceStarts.length; i++) {
      if (silenceStarts[i] > lastEnd) {
        segments.add({'start': lastEnd, 'end': silenceStarts[i]});
      }
      if (i < silenceEnds.length) {
        lastEnd = silenceEnds[i];
      }
    }

    // If no silence was detected, the entire audio is speech.
    // Return it as a single segment using the audio duration.
    if (segments.isEmpty) {
      final duration = await _getAudioDuration(inputPath);
      if (duration > 0) {
        segments.add({'start': 0.0, 'end': duration});
      }
    } else {
      // Add trailing speech after the last silence
      final duration = await _getAudioDuration(inputPath);
      if (duration > lastEnd + 0.5) {
        segments.add({'start': lastEnd, 'end': duration});
      }
    }

    return segments;
  }

  Future<double> _getAudioDuration(String inputPath) async {
    final completer = Completer<double>();
    await FFmpegKit.executeAsync('-i "$inputPath" -f null -', (session) async {
      final allLogs = await session.getAllLogsAsString();
      final match = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(allLogs ?? '');
      if (match != null) {
        final hours = int.parse(match.group(1)!);
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        final centiseconds = int.parse(match.group(4)!);
        completer.complete(hours * 3600.0 + minutes * 60.0 + seconds + centiseconds / 100.0);
      } else {
        completer.complete(0.0);
      }
    });
    return completer.future;
  }

  static List<Map<String, double>> _chunkSegments(
    List<Map<String, double>> segments, {
    double maxLen = 300.0,
    double overlap = 1.5,
  }) {
    final chunks = <Map<String, double>>[];

    for (final seg in segments) {
      double start = seg['start']!;
      final end = seg['end']!;

      while (start < end) {
        final chunkEnd = (start + maxLen).clamp(start, end);
        chunks.add({
          'start': (start - overlap).clamp(0.0, double.infinity),
          'end': chunkEnd + overlap,
        });
        start = chunkEnd;
      }
    }

    return chunks;
  }

  Future<String> _cutChunk(String inputPath, double start, double end, String outputPath) async {
    final completer = Completer<String>();
    final cmd = '-y -i "$inputPath" -ss $start -to $end -c:a aac -b:a 64k "$outputPath"';
    await FFmpegKit.executeAsync(cmd, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        completer.complete(outputPath);
        return;
      }
      final file = File(outputPath);
      if (await file.exists() && await file.length() > 0) {
        completer.complete(outputPath);
        return;
      }
      final logs = await session.getAllLogsAsString();
      completer.completeError(VoiceTranscriptionException('Failed to cut chunk: ${logs ?? "unknown error"}'));
    });
    return completer.future;
  }

  static Future<void> _deleteFile(String filePath) async {
    try {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  static Future<void> _deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // --- Main transcription pipeline ---

  Future<String?> transcribeFile(
    String filePath,
    String provider,
    String apiKey, {
    bool diarize = false,
    ProgressCallback? onProgress,
  }) async {
    final logger = TranscriptionLogger(DateTime.now().millisecondsSinceEpoch.toString(), onProgress: onProgress);

    logger.info('Starting transcription', data: {
      'filePath': filePath,
      'provider': provider,
      'diarize': diarize,
    });

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw VoiceTranscriptionException('Audio file missing.');
      }

      final fileSize = await file.length();
      logger.info('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB');

      String processedPath = filePath;
      final tempDir = await getTemporaryDirectory();
      final debugDir = _debugMode
          ? '${tempDir.path}/debug_${DateTime.now().millisecondsSinceEpoch}'
          : null;

      if (debugDir != null) {
        await Directory(debugDir).create(recursive: true);
      }

      // Only preprocess if > 10MB
      if (fileSize > 10 * 1024 * 1024) {
        logger.progress('Preprocessing audio...', 0.05);
        final processedFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.m4a');

        processedPath = await _preprocessAudio(filePath, processedFile.path);

        if (debugDir != null && await processedFile.exists()) {
          await processedFile.copy('$debugDir/processed.flac');
        }

        logger.info('Preprocessed file saved to: $processedPath');
      }

      // Detect silence / speech segments
      logger.progress('Analyzing audio segments...', 0.1);
      final segments = await _detectSilence(processedPath);
      logger.info('Found ${segments.length} speech segments');

      if (segments.isEmpty) {
        logger.progress('Transcribing whole file...', 0.3);
        final String? transcript;
        if (provider == 'openai') {
          transcript = await _transcribeWithOpenAI(processedPath, apiKey);
        } else {
          transcript = await _transcribeWithGemini(processedPath, apiKey, diarize: diarize);
        }
        if (transcript != null && transcript.isNotEmpty) {
          return transcript;
        }
        throw VoiceTranscriptionException('Transcription returned empty result');
      }

      // Chunk segments
      final chunks = _chunkSegments(segments);
      logger.info('Created ${chunks.length} chunks');

      // Clean up FFmpeg sessions before transcription
      await FFmpegKitConfig.clearSessions();

      // Prepare output directory for chunks
      final chunksDir = Directory('${tempDir.path}/chunks_${DateTime.now().millisecondsSinceEpoch}');
      await chunksDir.create();
      final chunkPaths = <String>[];

      // Cut chunks
      logger.progress('Preparing audio chunks...', 0.2);
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final chunkPath = '${chunksDir.path}/chunk_$i.m4a';
        await _cutChunk(processedPath, chunk['start']!, chunk['end']!, chunkPath);
        chunkPaths.add(chunkPath);

        if (debugDir != null) {
          final chunkFile = File(chunkPath);
          if (await chunkFile.exists()) {
            await chunkFile.copy('$debugDir/chunk_$i.flac');
          }
        }

        logger.debug('Created chunk $i: ${chunk['start']}s - ${chunk['end']}s');
      }

      // Transcribe chunks
      final transcriptParts = <String>[];
      for (var i = 0; i < chunkPaths.length; i++) {
        final progress = 0.3 + (0.6 * i / chunkPaths.length);
        logger.progress('Transcribing chunk ${i + 1}/${chunkPaths.length}...', progress);

        try {
          final String? transcript;
          if (provider == 'openai') {
            transcript = await _transcribeWithOpenAI(chunkPaths[i], apiKey);
          } else {
            transcript = await _transcribeWithGemini(chunkPaths[i], apiKey, diarize: diarize);
          }

          if (transcript != null && transcript.isNotEmpty) {
            transcriptParts.add(transcript);
            logger.debug('Chunk $i transcript length: ${transcript.length}');
          }
        } catch (e) {
          logger.error('Chunk $i transcription failed', data: {'error': e.toString()});
          throw VoiceTranscriptionException(e.toString(), i, logger.fullLog);
        }
      }

      // Cleanup temp files (unless debug mode)
      if (!_debugMode) {
        await _deleteDirectory(chunksDir.path);
        if (processedPath != filePath) {
          await _deleteFile(processedPath);
        }
      }

      logger.progress('Finalizing...', 0.95);
      final result = transcriptParts.join('\n\n');

      logger.info('Transcription complete', data: {
        'chunks': chunkPaths.length,
        'resultLength': result.length,
      });

      return result;
    } catch (e) {
      if (e is VoiceTranscriptionException) rethrow;
      throw VoiceTranscriptionException(e.toString(), null, logger.fullLog);
    }
  }

  Future<String?> transcribeWithOpenAI(String filePath, String apiKey) async {
    return _transcribeWithOpenAI(filePath, apiKey);
  }

  Future<String?> _transcribeWithOpenAI(String filePath, String apiKey) async {
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

  static const _geminiTranscriptionModel = 'google/gemini-3-flash-preview';

  static const _diarizationPrompt =
      'Transcribe this audio in full. Label each speaker as Speaker 1, Speaker 2, etc. '
      'If a word is unclear, write [inaudible] or your best guess in brackets like [unclear word?]. '
      'Format each line as:\n\n[MM:SS] Speaker X: <text>\n\n'
      'Maintain consistent speaker labels throughout. Do not summarize.';

  static const _transcriptionPrompt =
      'Transcribe this audio accurately. Output only the transcript.';

  Future<String?> _transcribeWithGemini(String filePath, String apiKey, {bool diarize = false}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw VoiceTranscriptionException('Audio file missing.');
    }

    final bytes = await file.readAsBytes();
    final audioB64 = base64Encode(bytes);
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
    final audioFormat = switch (ext) {
      'm4a' => 'mp4',
      'aac' => 'aac',
      'wav' => 'wav',
      'flac' => 'flac',
      'mp3' => 'mp3',
      'webm' => 'webm',
      _ => 'ogg',
    };

    final prompt = diarize ? _diarizationPrompt : _transcriptionPrompt;

    final response = await _http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/pashol/summsumm',
        'X-Title': 'AI Text Summarizer',
      },
      body: jsonEncode({
        'model': _geminiTranscriptionModel,
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
                'text': prompt,
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

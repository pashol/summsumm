import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';

Future<String> _convertToWav(String inputPath) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath = '${tempDir.path}/sherpa_input_${DateTime.now().millisecondsSinceEpoch}.wav';
  
  final cmd = '-y -i "$inputPath" -vn -ac 1 -ar 16000 -acodec pcm_s16le "$outputPath"';
  final session = await FFmpegKit.execute(cmd);
  final returnCode = await session.getReturnCode();
  
  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getAllLogsAsString();
    throw StateError('Failed to convert audio to WAV: $logs');
  }
  
  return outputPath;
}

class SherpaAsrEngine {
  sherpa.OfflineRecognizer? _recognizer;
  bool _isInitialized = false;

  Future<void> loadModel(WhisperModelConfig config) async {
    if (_isInitialized) return;

    sherpa.initBindings();

    final whisperConfig = sherpa.OfflineWhisperModelConfig(
      encoder: config.encoderPath,
      decoder: config.decoderPath,
    );

    final modelConfig = sherpa.OfflineModelConfig(
      whisper: whisperConfig,
      tokens: config.tokensPath,
      numThreads: 4,
      debug: false,
      provider: 'cpu',
    );

    final recognizerConfig = sherpa.OfflineRecognizerConfig(
      model: modelConfig,
    );

    _recognizer = sherpa.OfflineRecognizer(recognizerConfig);
    _isInitialized = true;
  }

  Future<String> transcribe(String audioPath) async {
    if (_recognizer == null) {
      throw StateError('Recognizer not initialized. Call loadModel() first.');
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw StateError('Audio file not found: $audioPath');
    }

    String wavPath = audioPath;
    bool needsCleanup = false;

    final ext = p.extension(audioPath).toLowerCase();
    if (ext != '.wav') {
      wavPath = await _convertToWav(audioPath);
      needsCleanup = true;
    }

    try {
      final wave = sherpa.readWave(wavPath);
      if (wave.samples.isEmpty) {
        throw StateError('Audio file contains no samples: $wavPath');
      }

      Float32List samples;
      if (wave.sampleRate != 16000) {
        samples = _resampleTo16k(wave.samples, wave.sampleRate);
      } else {
        samples = wave.samples;
      }

      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      final text = result.text;
      stream.free();
      
      return text;
    } finally {
      if (needsCleanup) {
        try {
          await File(wavPath).delete();
        } catch (_) {}
      }
    }
  }

  Float32List _resampleTo16k(Float32List samples, int sourceRate) {
    if (sourceRate == 16000) return samples;
    final ratio = 16000.0 / sourceRate;
    final newLength = (samples.length * ratio).round();
    final result = Float32List(newLength);
    for (var i = 0; i < newLength; i++) {
      final srcIdx = i / ratio;
      final idx0 = srcIdx.floor();
      final idx1 = (idx0 + 1).clamp(0, samples.length - 1);
      final frac = srcIdx - idx0;
      result[i] = samples[idx0] * (1 - frac) + samples[idx1] * frac;
    }
    return result;
  }

  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

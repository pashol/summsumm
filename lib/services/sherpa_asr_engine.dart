import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';

Float32List _convertPcmBytesToFloat32(Uint8List bytes) {
  final sampleCount = bytes.length ~/ 2;
  final values = Float32List(sampleCount);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    final short = data.getInt16(i * 2, Endian.little);
    values[i] = short / 32768.0;
  }
  return values;
}

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
      final bytes = await File(wavPath).readAsBytes();
      
      const wavHeaderSize = 44;
      if (bytes.length < wavHeaderSize) {
        throw StateError('Audio file too small: ${bytes.length} bytes');
      }
      
      final pcmBytes = bytes.sublist(wavHeaderSize);
      final samples = _convertPcmBytesToFloat32(pcmBytes);

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

  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

import 'dart:async';
import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/streaming_asr_engine.dart';
import 'package:summsumm/services/streaming_model_config.dart';

class RealTimeTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final StreamingAsrEngine _asrEngine;
  final _segmentController = StreamController<TranscriptSegment>.broadcast();
  bool _isRunning = false;
  final _buffer = BytesBuilder();
  String _fullTranscript = '';
  String _currentSegment = '';

  // Process every 0.5s = 8000 samples = 16000 bytes (16-bit)
  static const int _chunkSizeBytes = 16000;

  RealTimeTranscriptionService({
    ModelDownloadManager? downloadManager,
    StreamingAsrEngine? asrEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? StreamingAsrEngine();

  Stream<TranscriptSegment> get transcriptStream => _segmentController.stream;

  Future<void> start({required String language}) async {
    if (_isRunning) return;

    final config = StreamingModelConfigs.forLanguage(language);

    // Download model if needed
    if (!await _downloadManager.isStreamingModelAvailable(language)) {
      await _downloadManager.downloadStreamingModel(language);
    }

    // Load model
    final paths = await _downloadManager.getStreamingModelPaths(language);
    await _asrEngine.loadModel(StreamingModelConfig(
      name: config.name,
      url: config.url,
      encoderFile: paths['encoder']!,
      decoderFile: paths['decoder']!,
      joinerFile: paths['joiner']!,
      tokensFile: paths['tokens']!,
      language: config.language,
    ));

    _isRunning = true;
    _buffer.clear();
    _fullTranscript = '';
    _currentSegment = '';
  }

  void onAudioData(Uint8List pcm16Data) {
    if (!_isRunning) return;
    _buffer.add(pcm16Data);

    // Process when we have enough data
    while (_buffer.length >= _chunkSizeBytes) {
      final chunk = Uint8List.sublistView(
        _buffer.toBytes(), 0, _chunkSizeBytes
      );
      _processChunk(chunk);

      // Remove processed bytes
      final remaining = _buffer.toBytes().sublist(_chunkSizeBytes);
      _buffer.clear();
      _buffer.add(remaining);
    }
  }

  void _processChunk(Uint8List pcm16Data) {
    final samples = _convertPcm16ToFloat32(pcm16Data);
    _asrEngine.acceptWaveform(samples);

    final text = _asrEngine.decode();

    if (text.isNotEmpty && text != _currentSegment) {
      _currentSegment = text;
      _segmentController.add(TranscriptSegment(
        text: text,
        startTime: _asrEngine.currentTime - 0.5,
        endTime: _asrEngine.currentTime,
        isFinal: _asrEngine.isEndpoint(),
      ));
    }

    if (_asrEngine.isEndpoint()) {
      if (_currentSegment.isNotEmpty) {
        _fullTranscript += '$_currentSegment ';
      }
      _currentSegment = '';
      _asrEngine.reset();
    }
  }

  Future<String> stop() async {
    if (!_isRunning) return _fullTranscript;

    // Process remaining buffer
    if (_buffer.isNotEmpty) {
      final remaining = _buffer.toBytes();
      final samples = _convertPcm16ToFloat32(remaining);
      _asrEngine.acceptWaveform(samples);
    }

    // Final decode
    final finalText = _asrEngine.finalize();
    if (finalText.isNotEmpty) {
      _fullTranscript += finalText;
    }

    _isRunning = false;
    _buffer.clear();

    return _fullTranscript.trim();
  }

  Future<void> dispose() async {
    await stop();
    _asrEngine.dispose();
    _downloadManager.dispose();
    await _segmentController.close();
  }

  bool get isRunning => _isRunning;

  static Float32List _convertPcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final values = Float32List(sampleCount);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      final short = data.getInt16(i * 2, Endian.little);
      values[i] = short / 32768.0;
    }
    return values;
  }
}

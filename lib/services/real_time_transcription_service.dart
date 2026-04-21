import 'dart:async';
import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

class RealTimeTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final SherpaDiarizationEngine _diarizationEngine;
  final _segmentController = StreamController<TranscriptSegment>.broadcast();
  bool _isRunning = false;
  bool _diarize = false;
  final _buffer = <Uint8List>[];
  static const _bufferSize = 16000 * 2; // 1 second of 16kHz 16-bit audio

  RealTimeTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
    SherpaDiarizationEngine? diarizationEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine(),
        _diarizationEngine = diarizationEngine ?? SherpaDiarizationEngine();

  Stream<TranscriptSegment> get transcriptStream => _segmentController.stream;

  Future<void> start({
    required ModelSize modelSize,
    bool diarize = false,
  }) async {
    if (_isRunning) return;

    // Ensure models are downloaded
    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    // Load ASR model
    final modelPath = await _downloadManager.getModelPath(modelSize);
    final tokensPath = await _downloadManager.getTokensPath();
    await _asrEngine.loadModel(ModelConfig(
      modelPath: modelPath,
      tokensPath: tokensPath,
    ));

    // Create online stream
    await _asrEngine.createStream();

    // Load diarization model if needed
    _diarize = diarize;
    if (diarize) {
      if (!await _downloadManager.isSpeakerModelAvailable()) {
        await _downloadManager.downloadSpeakerModel();
      }
      final speakerModelPath = await _downloadManager.getSpeakerModelPath();
      await _diarizationEngine.loadModel(speakerModelPath);
      await _diarizationEngine.startSession();
    }

    _isRunning = true;
    _buffer.clear();
  }

  void onAudioData(Uint8List pcm16Data) {
    if (!_isRunning) return;

    _buffer.add(pcm16Data);
    final totalBytes = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);

    // Process when we have enough audio (1 second)
    if (totalBytes >= _bufferSize) {
      _processBuffer();
    }
  }

  Future<void> _processBuffer() async {
    if (_buffer.isEmpty) return;

    // Concatenate buffer
    final totalBytes = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(totalBytes);
    var offset = 0;
    for (final chunk in _buffer) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _buffer.clear();

    // Feed to ASR
    final text = await _asrEngine.acceptWaveform(combined);
    
    if (text != null && text.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: text,
        startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        endTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isFinal: false,
      ));
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    // Process remaining buffer
    await _processBuffer();

    // Finalize stream
    final finalText = await _asrEngine.finalizeStream();
    if (finalText.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: finalText,
        startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        endTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isFinal: true,
      ));
    }

    // Cleanup
    _asrEngine.destroyStream();
    if (_diarize) {
      await _diarizationEngine.endSession();
    }

    _isRunning = false;
  }

  Future<void> dispose() async {
    await stop();
    await _asrEngine.dispose();
    await _diarizationEngine.dispose();
    _downloadManager.dispose();
    await _segmentController.close();
  }

  bool get isRunning => _isRunning;
}

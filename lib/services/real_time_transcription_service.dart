import 'dart:async';
import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';

class RealTimeTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final _segmentController = StreamController<TranscriptSegment>.broadcast();
  bool _isRunning = false;
  final _buffer = <Uint8List>[];

  RealTimeTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine();

  Stream<TranscriptSegment> get transcriptStream => _segmentController.stream;

  Future<void> start({
    required ModelSize modelSize,
    bool diarize = false,
  }) async {
    if (_isRunning) return;

    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    final config = await _downloadManager.getModelConfig(modelSize);
    await _asrEngine.loadModel(config);

    _isRunning = true;
    _buffer.clear();
  }

  void onAudioData(Uint8List pcm16Data) {
    if (!_isRunning) return;
    _buffer.add(pcm16Data);
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    // Whisper is offline-only - transcription happens after recording
    // A full implementation would write PCM to WAV and transcribe
    if (_buffer.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: '[Transcription will be processed after recording stops]',
        startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        endTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isFinal: true,
      ));
    }

    _isRunning = false;
    _buffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _asrEngine.dispose();
    _downloadManager.dispose();
    await _segmentController.close();
  }

  bool get isRunning => _isRunning;
}

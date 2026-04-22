import 'dart:async';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';

class OnDeviceTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  bool _isInitialized = false;

  OnDeviceTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine();

  Future<void> initialize(ModelSize modelSize) async {
    if (_isInitialized) return;

    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    final config = await _downloadManager.getModelConfig(modelSize);
    await _asrEngine.loadModel(config);

    _isInitialized = true;
  }

  Future<String> transcribeFile(
    String audioPath, {
    bool diarize = false,
    void Function(String status, double? progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized. Call initialize() first.');
    }

    onProgress?.call('Loading audio…', 0.1);
    onProgress?.call('Transcribing audio…', 0.3);
    
    final transcript = await _asrEngine.transcribe(audioPath);

    onProgress?.call('Done', 1.0);
    return transcript;
  }

  Future<void> dispose() async {
    await _asrEngine.dispose();
    _downloadManager.dispose();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

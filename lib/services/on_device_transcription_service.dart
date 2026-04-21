import 'dart:async';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

class OnDeviceTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final SherpaDiarizationEngine _diarizationEngine;
  bool _isInitialized = false;

  OnDeviceTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
    SherpaDiarizationEngine? diarizationEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine(),
        _diarizationEngine = diarizationEngine ?? SherpaDiarizationEngine();

  Future<void> initialize(ModelSize modelSize) async {
    if (_isInitialized) return;

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

    // Load diarization model
    if (!await _downloadManager.isSpeakerModelAvailable()) {
      await _downloadManager.downloadSpeakerModel();
    }
    final speakerModelPath = await _downloadManager.getSpeakerModelPath();
    await _diarizationEngine.loadModel(speakerModelPath);

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

    // Transcribe audio
    onProgress?.call('Transcribing audio…', 0.3);
    final transcript = await _asrEngine.transcribe(audioPath);

    if (!diarize) {
      onProgress?.call('Done', 1.0);
      return transcript;
    }

    // Diarize
    onProgress?.call('Identifying speakers…', 0.7);
    // TODO: Parse transcript into words with timestamps for diarization
    // For now, return transcript without diarization
    
    onProgress?.call('Done', 1.0);
    return transcript;
  }

  Future<void> dispose() async {
    await _asrEngine.dispose();
    await _diarizationEngine.dispose();
    _downloadManager.dispose();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

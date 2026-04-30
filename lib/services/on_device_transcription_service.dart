import 'dart:async';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

typedef TranscriptionRunner = Future<String> Function(
  WhisperModelConfig config,
  String audioPath,
);

class OnDeviceTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final SherpaDiarizationEngine _diarizationEngine;
  final TranscriptionRunner _transcriptionRunner;
  bool _isInitialized = false;
  WhisperModelConfig? _modelConfig;

  OnDeviceTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
    SherpaDiarizationEngine? diarizationEngine,
    TranscriptionRunner? transcriptionRunner,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine(),
        _diarizationEngine = diarizationEngine ?? SherpaDiarizationEngine(),
        _transcriptionRunner =
            transcriptionRunner ?? SherpaAsrEngine.transcribeInBackground;

  Future<void> initialize(ModelSize modelSize) async {
    if (_isInitialized) return;

    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    _modelConfig = await _downloadManager.getModelConfig(modelSize);

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

    final transcript = await _transcriptionRunner(_modelConfig!, audioPath);

    onProgress?.call('Done', 1.0);
    return transcript;
  }

  Future<List<SpeakerSegment>> diarizeFile(String audioPath) async {
    await _diarizationEngine.loadModel();
    return await _diarizationEngine.diarize(audioPath);
  }

  Future<void> dispose() async {
    await _asrEngine.dispose();
    await _diarizationEngine.dispose();
    _downloadManager.dispose();
    _isInitialized = false;
    _modelConfig = null;
  }

  bool get isInitialized => _isInitialized;
}

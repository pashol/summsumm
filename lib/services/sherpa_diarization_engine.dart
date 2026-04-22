import 'dart:ffi';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

class SherpaDiarizationEngine {
  sherpa.OfflineSpeakerDiarization? _diarization;
  final ModelDownloadManager _downloadManager;
  bool _isInitialized = false;

  SherpaDiarizationEngine({ModelDownloadManager? downloadManager})
      : _downloadManager = downloadManager ?? ModelDownloadManager();

  Future<void> loadModel() async {
    if (_isInitialized) return;

    // Download models if needed
    if (!await _downloadManager.isSegmentationModelAvailable()) {
      await _downloadManager.downloadSegmentationModel();
    }
    if (!await _downloadManager.isEmbeddingModelAvailable()) {
      await _downloadManager.downloadEmbeddingModel();
    }

    final dir = await _downloadManager.getModelsDir();

    final segmentationConfig = sherpa.OfflineSpeakerSegmentationModelConfig(
      pyannote: sherpa.OfflineSpeakerSegmentationPyannoteModelConfig(
        model: '$dir/sherpa-onnx-pyannote-segmentation-3-0.onnx',
      ),
    );

    final embeddingConfig = sherpa.SpeakerEmbeddingExtractorConfig(
      model: '$dir/speaker-embedding.onnx',
    );

    final clusteringConfig = sherpa.FastClusteringConfig(
      numClusters: -1, // Auto-detect
      threshold: 0.5,
    );

    final config = sherpa.OfflineSpeakerDiarizationConfig(
      segmentation: segmentationConfig,
      embedding: embeddingConfig,
      clustering: clusteringConfig,
      minDurationOn: 0.2,
      minDurationOff: 0.5,
    );

    _diarization = sherpa.OfflineSpeakerDiarization(config);

    if (_diarization!.ptr == nullptr) {
      throw StateError('Failed to initialize diarization engine');
    }

    _isInitialized = true;
  }

  Future<List<SpeakerSegment>> diarize(String audioPath) async {
    if (!_isInitialized || _diarization == null) {
      throw StateError('Engine not initialized. Call loadModel() first.');
    }

    final waveData = sherpa.readWave(audioPath);

    if (_diarization!.sampleRate != waveData.sampleRate) {
      throw StateError(
        'Sample rate mismatch: expected ${_diarization!.sampleRate}, got ${waveData.sampleRate}'
      );
    }

    final segments = _diarization!.process(samples: waveData.samples);

    return segments.map((s) => SpeakerSegment(
      speakerLabel: 'Speaker ${s.speaker + 1}',
      startTime: s.start,
      endTime: s.end,
      text: '', // Text will be filled by caller
    )).toList();
  }

  Future<void> dispose() async {
    _diarization = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

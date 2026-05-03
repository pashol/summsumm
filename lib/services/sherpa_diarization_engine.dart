import 'dart:io';
import 'dart:ffi';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

Future<String> _convertToDiarizationWav(String inputPath) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath =
      '${tempDir.path}/sherpa_diarization_${DateTime.now().millisecondsSinceEpoch}.wav';

  if (Platform.isLinux) {
    final result = await Process.run('ffmpeg', [
      '-y', '-i', inputPath, '-vn', '-ac', '1', '-ar', '16000',
      '-acodec', 'pcm_s16le', outputPath,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Failed to convert audio to WAV for diarization: ${result.stderr}');
    }
    return outputPath;
  }

  final cmd =
      '-y -i "$inputPath" -vn -ac 1 -ar 16000 -acodec pcm_s16le "$outputPath"';
  final session = await FFmpegKit.execute(cmd);
  final returnCode = await session.getReturnCode();

  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getAllLogsAsString();
    throw StateError('Failed to convert audio to WAV for diarization: $logs');
  }

  return outputPath;
}

class SherpaDiarizationEngine {
  sherpa.OfflineSpeakerDiarization? _diarization;
  final ModelDownloadManager _downloadManager;
  bool _isInitialized = false;

  SherpaDiarizationEngine({ModelDownloadManager? downloadManager})
      : _downloadManager = downloadManager ?? ModelDownloadManager();

  Future<void> loadModel() async {
    if (_isInitialized) return;

    sherpa.initBindings();

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

    const clusteringConfig = sherpa.FastClusteringConfig(
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

    final file = File(audioPath);
    if (!await file.exists()) {
      throw StateError('Audio file not found: $audioPath');
    }

    String wavPath = audioPath;
    var needsCleanup = false;
    if (p.extension(audioPath).toLowerCase() != '.wav') {
      wavPath = await _convertToDiarizationWav(audioPath);
      needsCleanup = true;
    }

    try {
      final waveData = sherpa.readWave(wavPath);

      if (_diarization!.sampleRate != waveData.sampleRate) {
        throw StateError(
          'Sample rate mismatch: expected ${_diarization!.sampleRate}, got ${waveData.sampleRate}',
        );
      }

      final segments = _diarization!.process(samples: waveData.samples);

      return segments
          .map(
            (s) => SpeakerSegment(
              speakerLabel: 'Speaker ${s.speaker + 1}',
              startTime: s.start,
              endTime: s.end,
              text: '', // Text will be filled by caller
            ),
          )
          .toList();
    } finally {
      if (needsCleanup) {
        try {
          await File(wavPath).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> dispose() async {
    _diarization?.free();
    _diarization = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

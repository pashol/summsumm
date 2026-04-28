import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/streaming_model_config.dart';
import 'package:synchronized/synchronized.dart';

class ModelDownloadManager {
  final http.Client _client;
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final Lock _downloadLock = Lock();
  final Set<DownloadType> _activeDownloads = {};
  http.StreamedResponse? _currentResponse;
  bool _isCancelled = false;

  static const _modelUrls = {
    ModelSize.tiny:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2',
    ModelSize.base:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.tar.bz2',
    ModelSize.small:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2',
  };

  static const _modelNames = {
    ModelSize.tiny: 'tiny',
    ModelSize.base: 'base',
    ModelSize.small: 'small',
  };

  static DownloadType _modelSizeToType(ModelSize size) => switch (size) {
        ModelSize.tiny => DownloadType.whisperTiny,
        ModelSize.base => DownloadType.whisperBase,
        ModelSize.small => DownloadType.whisperSmall,
      };

  ModelDownloadManager({http.Client? client})
      : _client = client ?? http.Client();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  bool get isDownloading => _activeDownloads.isNotEmpty;

  void cancelDownload() {
    _isCancelled = true;
    _currentResponse?.stream.listen(null).cancel();
    _currentResponse = null;
  }

  Future<String> get _modelsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/sherpa_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<bool> isModelAvailable(ModelSize size) async {
    final dir = await _modelsDir;
    final modelName = _modelNames[size]!;
    final encoderFile = File('$dir/$modelName-encoder.int8.onnx');
    final decoderFile = File('$dir/$modelName-decoder.int8.onnx');
    final tokensFile = File('$dir/$modelName-tokens.txt');
    return await encoderFile.exists() &&
        await decoderFile.exists() &&
        await tokensFile.exists();
  }

  Future<bool> isSpeakerModelAvailable() async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/speaker-embedding.onnx');
    return await modelFile.exists();
  }

  Future<DownloadProgress> downloadModel(ModelSize size) async {
    final type = _modelSizeToType(size);

    if (_activeDownloads.contains(type)) {
      throw StateError('Model $size is already downloading');
    }

    return await _downloadLock.synchronized(() async {
      _activeDownloads.add(type);
      _isCancelled = false;

      final dir = await _modelsDir;
      final modelName = _modelNames[size]!;
      final tarPath = '$dir/$modelName.tar.bz2';

      _progressController.add(
        DownloadProgress(
          type: type,
          fraction: 0.0,
          status: DownloadStatus.downloading,
        ),
      );

      try {
        await _downloadFile(_modelUrls[size]!, tarPath, (fraction) {
          if (_isCancelled) {
            throw Exception('Download cancelled');
          }
          _progressController.add(
            DownloadProgress(
              type: type,
              fraction: fraction * 0.7,
              status: DownloadStatus.downloading,
            ),
          );
        });

        if (_isCancelled) {
          await File(tarPath).delete();
          _progressController.add(
            DownloadProgress(
              type: type,
              fraction: 0.0,
              status: DownloadStatus.cancelled,
            ),
          );
          return DownloadProgress(
            type: type,
            fraction: 0.0,
            status: DownloadStatus.cancelled,
          );
        }

        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 0.7,
            status: DownloadStatus.extracting,
          ),
        );

        await _extractTarBz2(tarPath, dir, modelName);

        await File(tarPath).delete();

        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 1.0,
            status: DownloadStatus.completed,
          ),
        );

        return DownloadProgress(
          type: type,
          fraction: 1.0,
          status: DownloadStatus.completed,
        );
      } catch (e) {
        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 0.0,
            status:
                _isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
          ),
        );
        rethrow;
      } finally {
        _activeDownloads.remove(type);
      }
    });
  }

  Future<void> _extractTarBz2(
    String tarPath,
    String destDir,
    String modelName,
  ) async {
    await compute(_extractInIsolate, {
      'tarPath': tarPath,
      'destDir': destDir,
      'modelName': modelName,
    });
  }

  static void _extractInIsolate(Map<String, dynamic> args) {
    final tarPath = args['tarPath'] as String;
    final destDir = args['destDir'] as String;
    final modelName = args['modelName'] as String;

    _extractSelectedTarBz2Files(tarPath, destDir, {
      'encoder.int8.onnx': '$destDir/$modelName-encoder.int8.onnx',
      'decoder.int8.onnx': '$destDir/$modelName-decoder.int8.onnx',
      'tokens.txt': '$destDir/$modelName-tokens.txt',
    });
  }

  Future<void> downloadSpeakerModel() async {
    final dir = await _modelsDir;
    final modelPath = '$dir/speaker-embedding.onnx';
    if (await File(modelPath).exists()) return;

    const url =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-ecapa-tdnn.tar.bz2';
    final tarPath = '$dir/speaker.tar.bz2';

    await _downloadFile(url, tarPath, (_) {});
    await _extractSpeakerModel(tarPath, dir);
    await File(tarPath).delete();
  }

  Future<void> _extractSpeakerModel(String tarPath, String destDir) async {
    await compute(_extractSpeakerInIsolate, {
      'tarPath': tarPath,
      'destDir': destDir,
    });
  }

  static void _extractSpeakerInIsolate(Map<String, dynamic> args) {
    final tarPath = args['tarPath'] as String;
    final destDir = args['destDir'] as String;

    _extractSelectedTarBz2Files(
      tarPath,
      destDir,
      const {'model.onnx': ''},
      fallbackOnnxOutputPath: '$destDir/speaker-embedding.onnx',
    );
  }

  Future<void> _downloadFile(
    String url,
    String path,
    void Function(double) onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = _currentResponse = await _client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    final file = File(path);
    final sink = file.openWrite();
    var downloadedBytes = 0;

    try {
      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          throw Exception('Download cancelled');
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await sink.close();
    } catch (e) {
      await sink.close();
      rethrow;
    } finally {
      _currentResponse = null;
    }
  }

  Future<Map<ModelSize, bool>> getDownloadedModels() async {
    final result = <ModelSize, bool>{};
    for (final size in ModelSize.values) {
      result[size] = await isModelAvailable(size);
    }
    return result;
  }

  Future<int> getModelSizeBytes(ModelSize size) async {
    final dir = await _modelsDir;
    final modelName = _modelNames[size]!;
    final files = [
      File('$dir/$modelName-encoder.int8.onnx'),
      File('$dir/$modelName-decoder.int8.onnx'),
      File('$dir/$modelName-tokens.txt'),
    ];
    var totalBytes = 0;
    for (final file in files) {
      if (await file.exists()) {
        totalBytes += await file.length();
      }
    }
    return totalBytes;
  }

  Future<void> deleteModel(ModelSize size) async {
    final dir = await _modelsDir;
    final modelName = _modelNames[size]!;
    final files = [
      '$dir/$modelName-encoder.int8.onnx',
      '$dir/$modelName-decoder.int8.onnx',
      '$dir/$modelName-tokens.txt',
    ];
    for (final f in files) {
      final file = File(f);
      if (await file.exists()) await file.delete();
    }
  }

  Future<WhisperModelConfig> getModelConfig(ModelSize size) async {
    final dir = await _modelsDir;
    final modelName = _modelNames[size]!;
    return WhisperModelConfig(
      encoderPath: '$dir/$modelName-encoder.int8.onnx',
      decoderPath: '$dir/$modelName-decoder.int8.onnx',
      tokensPath: '$dir/$modelName-tokens.txt',
    );
  }

  Future<String> getSpeakerModelPath() async {
    final dir = await _modelsDir;
    return '$dir/speaker-embedding.onnx';
  }

  // Streaming model methods
  Future<bool> isStreamingModelAvailable(String language) async {
    final config = StreamingModelConfigs.forLanguage(language);
    final dir = await _modelsDir;
    final encoder = File('$dir/${config.encoderFile}');
    final decoder = File('$dir/${config.decoderFile}');
    final joiner = File('$dir/${config.joinerFile}');
    final tokens = File('$dir/${config.tokensFile}');
    return await encoder.exists() &&
        await decoder.exists() &&
        await joiner.exists() &&
        await tokens.exists();
  }

  Future<DownloadProgress> downloadStreamingModel(String language) async {
    const type = DownloadType.streaming;

    if (_activeDownloads.contains(type)) {
      throw StateError('Streaming model is already downloading');
    }

    return await _downloadLock.synchronized(() async {
      _activeDownloads.add(type);
      _isCancelled = false;

      final config = StreamingModelConfigs.forLanguage(language);
      final dir = await _modelsDir;
      final tarPath = '$dir/streaming_model.tar.bz2';

      _progressController.add(
        const DownloadProgress(
          type: type,
          fraction: 0.0,
          status: DownloadStatus.downloading,
        ),
      );

      try {
        await _downloadFile(config.url, tarPath, (fraction) {
          if (_isCancelled) {
            throw Exception('Download cancelled');
          }
          _progressController.add(
            DownloadProgress(
              type: type,
              fraction: fraction * 0.7,
              status: DownloadStatus.downloading,
            ),
          );
        });

        if (_isCancelled) {
          await File(tarPath).delete();
          _progressController.add(
            const DownloadProgress(
              type: type,
              fraction: 0.0,
              status: DownloadStatus.cancelled,
            ),
          );
          return const DownloadProgress(
            type: type,
            fraction: 0.0,
            status: DownloadStatus.cancelled,
          );
        }

        _progressController.add(
          const DownloadProgress(
            type: type,
            fraction: 0.7,
            status: DownloadStatus.extracting,
          ),
        );

        await _extractStreamingModel(tarPath, dir, config);
        await File(tarPath).delete();

        _progressController.add(
          const DownloadProgress(
            type: type,
            fraction: 1.0,
            status: DownloadStatus.completed,
          ),
        );

        return const DownloadProgress(
          type: type,
          fraction: 1.0,
          status: DownloadStatus.completed,
        );
      } catch (e) {
        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 0.0,
            status:
                _isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
          ),
        );
        rethrow;
      } finally {
        _activeDownloads.remove(type);
      }
    });
  }

  Future<void> _extractStreamingModel(
    String tarPath,
    String destDir,
    StreamingModelConfig config,
  ) async {
    await compute(_extractStreamingInIsolate, {
      'tarPath': tarPath,
      'destDir': destDir,
      'config': config,
    });
  }

  static void _extractStreamingInIsolate(Map<String, dynamic> args) {
    final tarPath = args['tarPath'] as String;
    final destDir = args['destDir'] as String;
    final config = args['config'] as StreamingModelConfig;

    _extractSelectedTarBz2Files(tarPath, destDir, {
      config.encoderFile: '$destDir/${config.encoderFile}',
      config.decoderFile: '$destDir/${config.decoderFile}',
      config.joinerFile: '$destDir/${config.joinerFile}',
      config.tokensFile: '$destDir/${config.tokensFile}',
    });
  }

  Future<Map<String, String>> getStreamingModelPaths(String language) async {
    final config = StreamingModelConfigs.forLanguage(language);
    final dir = await _modelsDir;
    return {
      'encoder': '$dir/${config.encoderFile}',
      'decoder': '$dir/${config.decoderFile}',
      'joiner': '$dir/${config.joinerFile}',
      'tokens': '$dir/${config.tokensFile}',
    };
  }

  // Diarization model methods
  Future<bool> isSegmentationModelAvailable() async {
    final dir = await _modelsDir;
    return await File('$dir/sherpa-onnx-pyannote-segmentation-3-0.onnx')
        .exists();
  }

  Future<bool> isEmbeddingModelAvailable() async {
    final dir = await _modelsDir;
    return await File('$dir/speaker-embedding.onnx').exists();
  }

  Future<void> downloadEmbeddingModel() async {
    const type = DownloadType.embedding;

    if (_activeDownloads.contains(type)) {
      throw StateError('Embedding model is already downloading');
    }

    await _downloadLock.synchronized(() async {
      _activeDownloads.add(type);
      _isCancelled = false;

      final dir = await _modelsDir;
      final modelPath = '$dir/speaker-embedding.onnx';
      if (await File(modelPath).exists()) return;

      const url =
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx';

      _progressController.add(
        const DownloadProgress(
          type: type,
          fraction: 0.0,
          status: DownloadStatus.downloading,
        ),
      );

      try {
        await _downloadFile(url, modelPath, (fraction) {
          if (_isCancelled) {
            throw Exception('Download cancelled');
          }
          _progressController.add(
            DownloadProgress(
              type: type,
              fraction: fraction,
              status: DownloadStatus.downloading,
            ),
          );
        });

        _progressController.add(
          const DownloadProgress(
            type: type,
            fraction: 1.0,
            status: DownloadStatus.completed,
          ),
        );
      } catch (e) {
        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 0.0,
            status:
                _isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
          ),
        );
        rethrow;
      } finally {
        _activeDownloads.remove(type);
      }
    });
  }

  Future<void> downloadSegmentationModel() async {
    const type = DownloadType.segmentation;

    if (_activeDownloads.contains(type)) {
      throw StateError('Segmentation model is already downloading');
    }

    await _downloadLock.synchronized(() async {
      _activeDownloads.add(type);
      _isCancelled = false;

      final dir = await _modelsDir;
      final modelPath = '$dir/sherpa-onnx-pyannote-segmentation-3-0.onnx';
      if (await File(modelPath).exists()) return;

      const url =
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2';
      final tarPath = '$dir/segmentation.tar.bz2';

      _progressController.add(
        const DownloadProgress(
          type: type,
          fraction: 0.0,
          status: DownloadStatus.downloading,
        ),
      );

      try {
        await _downloadFile(url, tarPath, (fraction) {
          if (_isCancelled) {
            throw Exception('Download cancelled');
          }
          _progressController.add(
            DownloadProgress(
              type: type,
              fraction: fraction * 0.7,
              status: DownloadStatus.downloading,
            ),
          );
        });

        if (_isCancelled) {
          await File(tarPath).delete();
          _progressController.add(
            const DownloadProgress(
              type: type,
              fraction: 0.0,
              status: DownloadStatus.cancelled,
            ),
          );
          return;
        }

        _progressController.add(
          const DownloadProgress(
            type: type,
            fraction: 0.7,
            status: DownloadStatus.extracting,
          ),
        );

        await _extractSegmentationModel(tarPath, dir);
        await File(tarPath).delete();

        _progressController.add(
          const DownloadProgress(
            type: type,
            fraction: 1.0,
            status: DownloadStatus.completed,
          ),
        );
      } catch (e) {
        _progressController.add(
          DownloadProgress(
            type: type,
            fraction: 0.0,
            status:
                _isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
          ),
        );
        rethrow;
      } finally {
        _activeDownloads.remove(type);
      }
    });
  }

  Future<void> _extractSegmentationModel(String tarPath, String destDir) async {
    await compute(_extractSegmentationInIsolate, {
      'tarPath': tarPath,
      'destDir': destDir,
    });
  }

  static void _extractSegmentationInIsolate(Map<String, dynamic> args) {
    final tarPath = args['tarPath'] as String;
    final destDir = args['destDir'] as String;

    _extractSelectedTarBz2Files(tarPath, destDir, {
      'model.onnx': '$destDir/sherpa-onnx-pyannote-segmentation-3-0.onnx',
    });
  }

  static void _extractSelectedTarBz2Files(
    String tarBz2Path,
    String destDir,
    Map<String, String> outputPathByFileName, {
    String? fallbackOnnxOutputPath,
  }) {
    final tempTarPath = '$destDir/${p.basename(tarBz2Path)}.tar';
    final compressedInput = InputFileStream(tarBz2Path);
    final tarOutput = OutputFileStream(tempTarPath);

    try {
      BZip2Decoder().decodeStream(compressedInput, tarOutput);
    } finally {
      compressedInput.closeSync();
      tarOutput.closeSync();
    }

    final tarInput = InputFileStream(tempTarPath);
    try {
      TarDecoder().decodeStream(
        tarInput,
        callback: (entry) {
          if (!entry.isFile) return;

          final fileName = p.basename(entry.name);
          var outputPath = outputPathByFileName[fileName];
          outputPath ??= outputPathByFileName.entries
              .where((mapping) => fileName.endsWith(mapping.key))
              .map((mapping) => mapping.value)
              .firstOrNull;

          if ((outputPath == null || outputPath.isEmpty) &&
              fallbackOnnxOutputPath != null &&
              fileName.endsWith('.onnx')) {
            outputPath = fallbackOnnxOutputPath;
          }

          if (outputPath == null || outputPath.isEmpty) return;

          final output = OutputFileStream(outputPath);
          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
        },
      );
    } finally {
      tarInput.closeSync();
      final tempTar = File(tempTarPath);
      if (tempTar.existsSync()) tempTar.deleteSync();
    }
  }

  Future<String> getModelsDir() async => await _modelsDir;

  void dispose() {
    _progressController.close();
    _client.close();
  }
}

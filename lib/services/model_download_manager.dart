import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/transcription_config.dart';

class ModelDownloadManager {
  final http.Client _client;
  final _progressController = StreamController<DownloadProgress>.broadcast();

  static const _modelUrls = {
    ModelSize.base: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2',
    ModelSize.small: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.tar.bz2',
    ModelSize.medium: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2',
  };

  static const _modelNames = {
    ModelSize.base: 'tiny',
    ModelSize.small: 'base',
    ModelSize.medium: 'small',
  };

  ModelDownloadManager({http.Client? client}) : _client = client ?? http.Client();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

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
    final dir = await _modelsDir;
    final modelName = _modelNames[size]!;
    final tarPath = '$dir/$modelName.tar.bz2';

    _progressController.add(DownloadProgress(
      size: size,
      fraction: 0.0,
      status: DownloadStatus.downloading,
    ));

    try {
      await _downloadFile(_modelUrls[size]!, tarPath, (fraction) {
        _progressController.add(DownloadProgress(
          size: size,
          fraction: fraction * 0.7,
          status: DownloadStatus.downloading,
        ));
      });

      _progressController.add(DownloadProgress(
        size: size,
        fraction: 0.7,
        status: DownloadStatus.downloading,
      ));

      await _extractTarBz2(tarPath, dir, modelName);

      await File(tarPath).delete();

      _progressController.add(DownloadProgress(
        size: size,
        fraction: 1.0,
        status: DownloadStatus.completed,
      ));

      return DownloadProgress(
        size: size,
        fraction: 1.0,
        status: DownloadStatus.completed,
      );
    } catch (e) {
      _progressController.add(DownloadProgress(
        size: size,
        fraction: 0.0,
        status: DownloadStatus.failed,
      ));
      rethrow;
    }
  }

  Future<void> _extractTarBz2(String tarPath, String destDir, String modelName) async {
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

    final bytes = File(tarPath).readAsBytesSync();
    
    final bz2Decoder = BZip2Decoder();
    final tarBytes = bz2Decoder.decodeBytes(bytes);
    
    final tarArchive = TarDecoder().decodeBytes(tarBytes);
    
    for (final entry in tarArchive) {
      if (!entry.isFile) continue;
      
      final fileName = p.basename(entry.name);
      
      if (fileName.contains('encoder.int8.onnx')) {
        final outputPath = '$destDir/$modelName-encoder.int8.onnx';
        File(outputPath).writeAsBytesSync(entry.content as List<int>);
      } else if (fileName.contains('decoder.int8.onnx')) {
        final outputPath = '$destDir/$modelName-decoder.int8.onnx';
        File(outputPath).writeAsBytesSync(entry.content as List<int>);
      } else if (fileName.endsWith('tokens.txt')) {
        final outputPath = '$destDir/$modelName-tokens.txt';
        File(outputPath).writeAsBytesSync(entry.content as List<int>);
      }
    }
  }

  Future<void> downloadSpeakerModel() async {
    final dir = await _modelsDir;
    final modelPath = '$dir/speaker-embedding.onnx';
    if (await File(modelPath).exists()) return;
    
    const url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-ecapa-tdnn.tar.bz2';
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

    final bytes = File(tarPath).readAsBytesSync();
    final bz2Decoder = BZip2Decoder();
    final tarBytes = bz2Decoder.decodeBytes(bytes);
    final tarArchive = TarDecoder().decodeBytes(tarBytes);

    for (final entry in tarArchive) {
      if (!entry.isFile) continue;
      final fileName = p.basename(entry.name);
      if (fileName == 'model.onnx' || fileName.endsWith('.onnx')) {
        File('$destDir/speaker-embedding.onnx').writeAsBytesSync(entry.content as List<int>);
        break;
      }
    }
  }

  Future<void> _downloadFile(String url, String path, void Function(double) onProgress) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    final file = File(path);
    final sink = file.openWrite();
    var downloadedBytes = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    await sink.close();
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

  void dispose() {
    _progressController.close();
    _client.close();
  }
}

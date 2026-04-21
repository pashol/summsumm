import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/transcription_config.dart';

class ModelDownloadManager {
  final http.Client _client;
  final _progressController = StreamController<DownloadProgress>.broadcast();
  
  static const _modelUrls = {
    ModelSize.base: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-model.onnx',
    ModelSize.small: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-model.onnx',
    ModelSize.medium: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-medium/resolve/main/medium-model.onnx',
  };
  
  static const _tokensUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/tokens.txt';
  static const _speakerModelUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-ecapa-tdnn/resolve/main/model.onnx';

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
    final modelFile = File('$dir/whisper-${size.name}.onnx');
    final tokensFile = File('$dir/tokens.txt');
    return await modelFile.exists() && await tokensFile.exists();
  }

  Future<bool> isSpeakerModelAvailable() async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/speaker-embedding.onnx');
    return await modelFile.exists();
  }

  Future<DownloadProgress> downloadModel(ModelSize size) async {
    final dir = await _modelsDir;
    final modelPath = '$dir/whisper-${size.name}.onnx';
    final tokensPath = '$dir/tokens.txt';

    _progressController.add(DownloadProgress(
      size: size,
      fraction: 0.0,
      status: DownloadStatus.downloading,
    ));

    try {
      // Download model
      await _downloadFile(_modelUrls[size]!, modelPath, (fraction) {
        _progressController.add(DownloadProgress(
          size: size,
          fraction: fraction * 0.9,
          status: DownloadStatus.downloading,
        ));
      });

      // Download tokens (only if not exists)
      if (!await File(tokensPath).exists()) {
        await _downloadFile(_tokensUrl, tokensPath, (_) {});
      }

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

  Future<void> downloadSpeakerModel() async {
    final dir = await _modelsDir;
    final modelPath = '$dir/speaker-embedding.onnx';
    if (await File(modelPath).exists()) return;
    await _downloadFile(_speakerModelUrl, modelPath, (_) {});
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

  Future<void> deleteModel(ModelSize size) async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/whisper-${size.name}.onnx');
    if (await modelFile.exists()) await modelFile.delete();
  }

  Future<String> getModelPath(ModelSize size) async {
    final dir = await _modelsDir;
    return '$dir/whisper-${size.name}.onnx';
  }

  Future<String> getTokensPath() async {
    final dir = await _modelsDir;
    return '$dir/tokens.txt';
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

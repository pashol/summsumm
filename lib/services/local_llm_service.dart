import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

const _kGemmaModelName = 'gemma-3-1b-it-gpu-int8.task';
const _kGemmaModelUrl =
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma-3-1b-it-gpu-int8.task';

class LocalLlmService {
  InferenceModel? _model;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  bool get isModelReady => _model != null;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  Future<bool> isModelInstalled() async {
    return FlutterGemma.isModelInstalled(_kGemmaModelName);
  }

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (await isModelInstalled()) return;
    _isDownloading = true;
    _downloadProgress = 0;
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(_kGemmaModelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        onProgress?.call(_downloadProgress);
      }).install();
    } finally {
      _isDownloading = false;
      _downloadProgress = 0;
    }
  }

  Future<void> ensureModelLoaded() async {
    if (_model != null) return;

    final installed = await isModelInstalled();
    if (!installed) throw StateError('Model not downloaded. Call downloadModel() first.');

    _model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async* {
    if (_model == null) throw StateError('Model not ready. Call ensureModelLoaded() first.');

    final chat = await _model!.createChat(
      systemInstruction: systemPrompt,
      temperature: 0.8,
      topK: 3,
    );

    for (final message in messages) {
      final content = message['content'];
      if (content is! String) {
        throw ArgumentError('Message content must be a String, got: $content');
      }
      final role = message['role'];
      if (role is! String) {
        throw ArgumentError('Message role must be a String, got: $role');
      }
      final isUser = role == 'user';
      await chat.addQueryChunk(Message.text(text: content, isUser: isUser));
    }

    StreamSubscription<dynamic>? sub;
    final controller = StreamController<String>(
      onCancel: () => sub?.cancel(),
    );
    sub = chat.generateChatResponseAsync().listen(
      (response) {
        if (response is TextResponse) {
          controller.add(response.token);
        }
      },
      onError: (Object e) {
        controller.addError(e);
      },
      onDone: () {
        controller.close();
      },
      cancelOnError: true,
    );
    try {
      yield* controller.stream;
    } finally {
      await sub.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<void> close() async {
    await _model?.close();
    _model = null;
  }
}

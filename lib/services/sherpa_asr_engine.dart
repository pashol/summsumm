import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';

// Stub types for sherpa_onnx — will be replaced when the package is added.
// ignore: constant_identifier_names
const bool _sherpaAvailable = false;

class _OfflineRecognizer {
  _OfflineStream createStream() => _OfflineStream();
  void decode(_OfflineStream stream) {}
  _RecognitionResult getResult(_OfflineStream stream) => _RecognitionResult();
  void free() {}
}

class _OnlineRecognizer {
  _OnlineStream createStream() => _OnlineStream();
  bool isReady(_OnlineStream stream) => false;
  void decode(_OnlineStream stream) {}
  _RecognitionResult getResult(_OnlineStream stream) => _RecognitionResult();
  void inputFinished(_OnlineStream stream) {}
  void free() {}
}

class _OfflineStream {
  void acceptWaveFile(String path) {}
  void free() {}
}

class _OnlineStream {
  void acceptWaveform({required Uint8List samples, required int sampleRate}) {}
  void free() {}
}

class _RecognitionResult {
  String text = '';
}

class _FeatureExtractorConfig {
  final int samplingRate;
  final int featureDim;
  _FeatureExtractorConfig({required this.samplingRate, required this.featureDim});
}

class _OfflineWhisperModelConfig {
  final String encoder;
  final String decoder;
  _OfflineWhisperModelConfig({required this.encoder, required this.decoder});
}

class _OfflineModelConfig {
  final _OfflineWhisperModelConfig whisper;
  final String tokens;
  _OfflineModelConfig({required this.whisper, required this.tokens});
}

class _OfflineRecognizerConfig {
  final _OfflineModelConfig modelConfig;
  final _FeatureExtractorConfig featConfig;
  _OfflineRecognizerConfig({required this.modelConfig, required this.featConfig});
}

class _OnlineTransducerModelConfig {
  final String encoder;
  final String decoder;
  final String joiner;
  _OnlineTransducerModelConfig({required this.encoder, required this.decoder, required this.joiner});
}

class _OnlineModelConfig {
  final _OnlineTransducerModelConfig transducer;
  final String tokens;
  _OnlineModelConfig({required this.transducer, required this.tokens});
}

class _OnlineRecognizerConfig {
  final _OnlineModelConfig modelConfig;
  final _FeatureExtractorConfig featConfig;
  _OnlineRecognizerConfig({required this.modelConfig, required this.featConfig});
}

class SherpaAsrEngine {
  _OfflineRecognizer? _offlineRecognizer;
  _OnlineRecognizer? _onlineRecognizer;
  _OnlineStream? _onlineStream;
  bool _isInitialized = false;

  Future<void> loadModel(ModelConfig config) async {
    if (_isInitialized) return;

    if (!_sherpaAvailable) {
      // Package not yet available — initialize stubbed recognizers for API compatibility.
      _offlineRecognizer = _OfflineRecognizer();
      _onlineRecognizer = _OnlineRecognizer();
      _isInitialized = true;
      return;
    }

    // Configure feature extractor
    final featConfig = _FeatureExtractorConfig(
      samplingRate: config.sampleRate,
      featureDim: config.featureDim,
    );

    // Configure offline recognizer (for batch transcription)
    final offlineModelConfig = _OfflineModelConfig(
      whisper: _OfflineWhisperModelConfig(
        encoder: config.encoderPath ?? '',
        decoder: config.decoderPath ?? '',
      ),
      tokens: config.tokensPath,
    );

    _offlineRecognizer = _OfflineRecognizer();

    // Configure online recognizer (for streaming)
    final onlineModelConfig = _OnlineModelConfig(
      transducer: _OnlineTransducerModelConfig(
        encoder: config.encoderPath ?? '',
        decoder: config.decoderPath ?? '',
        joiner: '',
      ),
      tokens: config.tokensPath,
    );

    _onlineRecognizer = _OnlineRecognizer();

    _isInitialized = true;
  }

  // --- Offline (Batch) Mode ---

  Future<String> transcribe(String audioPath) async {
    if (_offlineRecognizer == null) {
      throw StateError('Offline recognizer not initialized. Call loadModel() first.');
    }

    final stream = _offlineRecognizer!.createStream();
    stream.acceptWaveFile(audioPath);
    _offlineRecognizer!.decode(stream);
    
    final result = _offlineRecognizer!.getResult(stream);
    stream.free();
    
    return result.text;
  }

  // --- Online (Streaming) Mode ---

  Future<void> createStream() async {
    if (_onlineRecognizer == null) {
      throw StateError('Online recognizer not initialized. Call loadModel() first.');
    }
    _onlineStream = _onlineRecognizer!.createStream();
  }

  Future<String?> acceptWaveform(Uint8List pcm16Data) async {
    if (_onlineRecognizer == null || _onlineStream == null) {
      throw StateError('Online recognizer not initialized or stream not created.');
    }

    _onlineStream!.acceptWaveform(
      samples: pcm16Data,
      sampleRate: 16000,
    );

    while (_onlineRecognizer!.isReady(_onlineStream!)) {
      _onlineRecognizer!.decode(_onlineStream!);
    }

    final result = _onlineRecognizer!.getResult(_onlineStream!);
    return result.text.isEmpty ? null : result.text;
  }

  Future<String> finalizeStream() async {
    if (_onlineRecognizer == null || _onlineStream == null) {
      throw StateError('Online recognizer not initialized or stream not created.');
    }

    _onlineRecognizer!.inputFinished(_onlineStream!);
    
    while (_onlineRecognizer!.isReady(_onlineStream!)) {
      _onlineRecognizer!.decode(_onlineStream!);
    }

    final result = _onlineRecognizer!.getResult(_onlineStream!);
    return result.text;
  }

  void destroyStream() {
    _onlineStream?.free();
    _onlineStream = null;
  }

  // --- Lifecycle ---

  Future<void> dispose() async {
    _offlineRecognizer?.free();
    _offlineRecognizer = null;
    _onlineRecognizer?.free();
    _onlineRecognizer = null;
    _onlineStream?.free();
    _onlineStream = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

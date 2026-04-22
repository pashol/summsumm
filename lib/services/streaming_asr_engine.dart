import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';

class StreamingAsrEngine {
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  bool _isInitialized = false;
  double _currentTime = 0.0;

  Future<void> loadModel(StreamingModelConfig config) async {
    if (_isInitialized) {
      throw StateError('Engine already initialized. Call dispose() first to load a different model.');
    }

    sherpa.initBindings();

    final modelConfig = sherpa.OnlineModelConfig(
      transducer: sherpa.OnlineTransducerModelConfig(
        encoder: config.encoderFile,
        decoder: config.decoderFile,
        joiner: config.joinerFile,
      ),
      tokens: config.tokensFile,
      numThreads: 4,
      debug: false,
      provider: 'cpu',
    );

    final recognizerConfig = sherpa.OnlineRecognizerConfig(
      model: modelConfig,
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20.0,
    );

    _recognizer = sherpa.OnlineRecognizer(recognizerConfig);
    _stream = _recognizer!.createStream();
    _isInitialized = true;
  }

  void acceptWaveform(Float32List samples, {int sampleRate = 16000}) {
    if (_stream == null || _recognizer == null) {
      throw StateError('Engine not initialized. Call loadModel() first.');
    }

    if (sampleRate != 16000) {
      throw ArgumentError('Sample rate must be 16000, got $sampleRate');
    }

    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);
    _currentTime += samples.length / sampleRate;
  }

  String decode() {
    if (_stream == null || _recognizer == null) return '';

    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }

    final result = _recognizer!.getResult(_stream!);
    return result.text;
  }

  bool isEndpoint() {
    if (_stream == null || _recognizer == null) return false;
    return _recognizer!.isEndpoint(_stream!);
  }

  void reset() {
    if (_stream == null || _recognizer == null) return;
    _recognizer!.reset(_stream!);
  }

  String finalize() {
    if (_stream == null || _recognizer == null) return '';

    // Process any remaining audio
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }
    final result = _recognizer!.getResult(_stream!);
    return result.text;
  }

  double get currentTime => _currentTime;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _stream?.free();
    _recognizer?.free();
    _stream = null;
    _recognizer = null;
    _isInitialized = false;
    _currentTime = 0.0;
  }
}

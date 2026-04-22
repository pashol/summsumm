import 'package:summsumm/models/transcription_config.dart';

class StreamingModelConfigs {
  static const english = StreamingModelConfig(
    name: 'sherpa-onnx-streaming-zipformer-en-20M',
    url: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2',
    encoderFile: 'encoder-epoch-99-avg-1.int8.onnx',
    decoderFile: 'decoder-epoch-99-avg-1.int8.onnx',
    joinerFile: 'joiner-epoch-99-avg-1.int8.onnx',
    tokensFile: 'tokens.txt',
    language: 'English',
  );

  static StreamingModelConfig forLanguage(String language) {
    switch (language) {
      case 'English':
        return english;
      case 'German':
        // No German streaming model available — fallback to English with warning
        return english;
      default:
        return english;
    }
  }

  static bool isSupported(String language) {
    return language == 'English';
  }
}

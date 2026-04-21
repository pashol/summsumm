import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';

void main() {
  group('SherpaAsrEngine', () {
    late SherpaAsrEngine engine;

    setUp(() {
      engine = SherpaAsrEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('isInitialized is false before loadModel', () {
      expect(engine.isInitialized, false);
    });

    test('transcribe throws when not initialized', () async {
      expect(
        () => engine.transcribe('test.wav'),
        throwsStateError,
      );
    });

    test('acceptWaveform throws when stream not created', () async {
      await engine.loadModel(const ModelConfig(
        modelPath: 'test.onnx',
        tokensPath: 'tokens.txt',
      ));
      
      expect(
        () => engine.acceptWaveform(Uint8List(0)),
        throwsStateError,
      );
    });
  });
}

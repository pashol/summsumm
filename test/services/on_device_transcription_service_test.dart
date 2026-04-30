import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';

class _FakeDownloadManager extends ModelDownloadManager {
  final config = const WhisperModelConfig(
    encoderPath: '/models/base-encoder.onnx',
    decoderPath: '/models/base-decoder.onnx',
    tokensPath: '/models/base-tokens.txt',
  );

  @override
  Future<bool> isModelAvailable(ModelSize size) async => true;

  @override
  Future<WhisperModelConfig> getModelConfig(ModelSize size) async => config;
}

class _TrackingAsrEngine extends SherpaAsrEngine {
  var loadModelCalls = 0;
  var transcribeCalls = 0;

  @override
  Future<void> loadModel(WhisperModelConfig config) async {
    loadModelCalls++;
  }

  @override
  Future<String> transcribe(String audioPath) async {
    transcribeCalls++;
    throw StateError('main isolate transcribe should not be called');
  }
}

void main() {
  group('OnDeviceTranscriptionService', () {
    late OnDeviceTranscriptionService service;

    setUp(() {
      service = OnDeviceTranscriptionService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isInitialized is false before initialize', () {
      expect(service.isInitialized, false);
    });

    test('transcribeFile throws when not initialized', () async {
      expect(
        () => service.transcribeFile('test.wav'),
        throwsStateError,
      );
    });

    test('transcribes through background runner after caching model config',
        () async {
      final downloadManager = _FakeDownloadManager();
      final asrEngine = _TrackingAsrEngine();
      WhisperModelConfig? runnerConfig;
      String? runnerAudioPath;
      final service = OnDeviceTranscriptionService(
        downloadManager: downloadManager,
        asrEngine: asrEngine,
        transcriptionRunner: (config, audioPath) async {
          runnerConfig = config;
          runnerAudioPath = audioPath;
          return 'background transcript';
        },
      );
      addTearDown(service.dispose);

      await service.initialize(ModelSize.base);
      final transcript = await service.transcribeFile('/audio/meeting.m4a');

      expect(transcript, 'background transcript');
      expect(runnerConfig, same(downloadManager.config));
      expect(runnerAudioPath, '/audio/meeting.m4a');
      expect(asrEngine.loadModelCalls, 0);
      expect(asrEngine.transcribeCalls, 0);
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync().path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  group('ModelDownloadManager', () {
    late ModelDownloadManager manager;

    setUp(() {
      manager = ModelDownloadManager(client: http.Client());
    });

    tearDown(() {
      manager.dispose();
    });

    test('isModelAvailable returns false when model not downloaded', () async {
      final available = await manager.isModelAvailable(ModelSize.tiny);
      expect(available, false);
    });

    test('getModelConfig returns correct paths', () async {
      final config = await manager.getModelConfig(ModelSize.tiny);
      expect(config.encoderPath, contains('tiny-encoder.int8.onnx'));
      expect(config.decoderPath, contains('tiny-decoder.int8.onnx'));
      expect(config.tokensPath, contains('tiny-tokens.txt'));
    });
  });
}

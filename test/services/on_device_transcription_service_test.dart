import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';

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
  });
}

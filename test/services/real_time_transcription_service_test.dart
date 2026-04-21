import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/real_time_transcription_service.dart';

void main() {
  group('RealTimeTranscriptionService', () {
    late RealTimeTranscriptionService service;

    setUp(() {
      service = RealTimeTranscriptionService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isRunning is false before start', () {
      expect(service.isRunning, false);
    });

    test('onAudioData does nothing when not running', () {
      // Should not throw
      service.onAudioData(Uint8List(0));
    });
  });
}

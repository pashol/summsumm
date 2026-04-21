import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

void main() {
  group('SherpaDiarizationEngine', () {
    late SherpaDiarizationEngine engine;

    setUp(() {
      engine = SherpaDiarizationEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('isInitialized is false before loadModel', () {
      expect(engine.isInitialized, false);
    });

    test('diarize throws when not initialized', () async {
      expect(
        () => engine.diarize('test.wav', []),
        throwsStateError,
      );
    });
  });
}

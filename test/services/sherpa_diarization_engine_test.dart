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

    test('diarize returns empty list (not yet implemented)', () async {
      final result = await engine.diarize('test.wav', []);
      expect(result, isEmpty);
    });
  });
}

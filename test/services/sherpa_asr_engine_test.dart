import 'package:flutter_test/flutter_test.dart';
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
  });
}

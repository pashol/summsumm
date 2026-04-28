import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/utils/audio_seek_state.dart';

void main() {
  group('AudioSeekState', () {
    test('uses dragged slider value until seek ends', () {
      final state = AudioSeekState();
      const duration = Duration(seconds: 100);

      expect(
        state.sliderValue(
          position: const Duration(seconds: 10),
          duration: duration,
        ),
        0.1,
      );

      state.updateDragValue(0.7);

      expect(state.isSeeking, isTrue);
      expect(
        state.sliderValue(
          position: const Duration(seconds: 12),
          duration: duration,
        ),
        0.7,
      );
      expect(state.acceptsPlaybackPosition, isFalse);

      final seekPosition = state.finishSeek(0.7, duration);

      expect(seekPosition, const Duration(seconds: 70));
      expect(state.isSeeking, isFalse);
      expect(state.acceptsPlaybackPosition, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/summary_state.dart';

void main() {
  group('SummaryState', () {
    test('initial state has expected defaults', () {
      final state = SummaryState.initial();
      expect(state.status, SummaryStatus.idle);
      expect(state.summary, '');
      expect(state.error, '');
      expect(state.chat, isEmpty);
      expect(state.followUpCount, 0);
      expect(state.isSpeaking, isFalse);
      expect(state.ttsState, TtsState.stopped);
      expect(state.isCursorVisible, isTrue);
      expect(state.streamingReply, '');
      expect(state.isFactChecking, isFalse);
    });

    test('copyWith replaces only specified fields', () {
      final initial = SummaryState.initial();
      final updated = initial.copyWith(
        status: SummaryStatus.streaming,
        summary: 'Hello',
      );
      expect(updated.status, SummaryStatus.streaming);
      expect(updated.summary, 'Hello');
      expect(updated.followUpCount, 0);
      expect(updated.isSpeaking, isFalse);
    });

    test('copyWith preserves unspecified fields', () {
      final state = SummaryState.initial().copyWith(
        status: SummaryStatus.done,
        summary: 'Test summary',
        followUpCount: 2,
      );
      final updated = state.copyWith(followUpCount: 3);
      expect(updated.status, SummaryStatus.done);
      expect(updated.summary, 'Test summary');
      expect(updated.followUpCount, 3);
    });
  });

  group('SummaryStatus', () {
    test('has all expected values', () {
      expect(
        SummaryStatus.values,
        containsAll([
          SummaryStatus.idle,
          SummaryStatus.loading,
          SummaryStatus.streaming,
          SummaryStatus.done,
          SummaryStatus.error,
        ]),
      );
    });
  });
}

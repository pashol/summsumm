import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/providers/meeting_chat_provider.dart';

void main() {
  test('initial state has empty messages and is not streaming', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(meetingChatProvider('test-id'));
    expect(state.messages, isEmpty);
    expect(state.isStreaming, false);
    expect(state.error, isNull);
  });

  test('different meetingIds get independent state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final aNotifier = container.read(meetingChatProvider('a').notifier);
    final bNotifier = container.read(meetingChatProvider('b').notifier);
    expect(aNotifier, isNot(same(bNotifier)));
  });
}
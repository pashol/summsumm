import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/ask_library_chat_provider.dart';

void main() {
  test('initial chat state is empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(askLibraryChatProvider);

    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);
  });

  test('new chat clears messages and errors', () {
    final container = ProviderContainer(
      overrides: [
        askLibraryChatProvider.overrideWith(
          (ref) => TestAskLibraryChatNotifier(
            ref,
            const AskLibraryChatState(
              messages: [AskLibraryMessage(role: 'user', content: 'Question')],
              isStreaming: true,
              error: 'Failed',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(askLibraryChatProvider.notifier);

    notifier.newChat();

    final state = container.read(askLibraryChatProvider);
    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);
  });
}

class TestAskLibraryChatNotifier extends AskLibraryChatNotifier {
  TestAskLibraryChatNotifier(super.ref, AskLibraryChatState initialState) {
    state = initialState;
  }
}

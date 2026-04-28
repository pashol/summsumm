import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/local_llm_service.dart';

void main() {
  test('isModelReady returns false when not initialized', () {
    final service = LocalLlmService();
    expect(service.isModelReady, isFalse);
  });

  test('streamChat throws when model not ready', () async {
    final service = LocalLlmService();
    final stream = service.streamChat(
      systemPrompt: 'test',
      messages: [{'role': 'user', 'content': 'hi'}],
    );
    await expectLater(
      stream,
      emitsError(isA<StateError>()),
    );
  });

  // NOTE: Integration tests for streamChat (e.g., subscription cancellation,
  // resource cleanup) require mocking the flutter_gemma platform channel,
  // which is not easily done in unit tests. Consider adding widget/integration
  // tests for full streamChat coverage.
}

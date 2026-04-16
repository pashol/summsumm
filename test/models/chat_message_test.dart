import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('toApiMap returns correct role and content', () {
      const msg = ChatMessage(role: 'user', content: 'Hello');
      expect(msg.toApiMap(), {'role': 'user', 'content': 'Hello'});
    });

    test('assistant message serializes correctly', () {
      const msg = ChatMessage(role: 'assistant', content: 'Summary text');
      expect(msg.toApiMap(), {'role': 'assistant', 'content': 'Summary text'});
    });
  });
}

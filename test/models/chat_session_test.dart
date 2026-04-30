import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_session.dart';
import 'package:summsumm/models/chat_message.dart';

void main() {
  test('ChatSession serializes and deserializes', () {
    final session = ChatSession(
      id: 'test-id',
      title: 'Q: Hello world',
      createdAt: DateTime(2025, 1, 28),
      updatedAt: DateTime(2025, 1, 28, 12),
      messages: [
        const ChatMessage(role: 'user', content: 'Hello'),
        const ChatMessage(role: 'assistant', content: 'Hi there'),
      ],
    );
    
    final json = session.toJson();
    final restored = ChatSession.fromJson(json);
    
    expect(restored.id, 'test-id');
    expect(restored.title, 'Q: Hello world');
    expect(restored.messages.length, 2);
    expect(restored.messages[0].content, 'Hello');
  });
}

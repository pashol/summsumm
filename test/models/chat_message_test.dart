import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_message.dart';

void main() {
  test('ChatMessage with metadata serializes to JSON', () {
    const message = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'citations': [{'title': 'Doc 1'}]},
    );
    final json = message.toApiMap();
    expect(json['metadata'], isNotNull);
    expect(json['metadata']['citations'][0]['title'], 'Doc 1');
  });
}

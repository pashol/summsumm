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

  test('toApiMap excludes metadata when null', () {
    const message = ChatMessage(role: 'user', content: 'Hello');
    final json = message.toApiMap();
    expect(json.containsKey('metadata'), isFalse);
    expect(json, {'role': 'user', 'content': 'Hello'});
  });

  test('fromJson deserializes metadata', () {
    final json = {
      'role': 'assistant',
      'content': 'Hello',
      'metadata': {
        'citations': [
          {'title': 'Doc 1'},
        ],
      },
    };
    final message = ChatMessage.fromJson(json);
    expect(message.metadata, isNotNull);
    expect(message.metadata!['citations'][0]['title'], 'Doc 1');
  });

  test('fromJson handles missing metadata', () {
    final json = {'role': 'user', 'content': 'Hello'};
    final message = ChatMessage.fromJson(json);
    expect(message.metadata, isNull);
  });

  test('== uses deep equality for metadata', () {
    final a = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {
        'citations': [
          {'title': 'Doc 1'},
        ],
      },
    );
    final b = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {
        'citations': [
          {'title': 'Doc 1'},
        ],
      },
    );
    expect(a, equals(b));
    expect(a == b, isTrue);
  });

  test('== returns false when metadata differs', () {
    final a = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'key': 'value1'},
    );
    final b = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'key': 'value2'},
    );
    expect(a == b, isFalse);
  });

  test('hashCode is consistent for equal objects with metadata', () {
    final a = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {
        'citations': [
          {'title': 'Doc 1'},
        ],
      },
    );
    final b = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {
        'citations': [
          {'title': 'Doc 1'},
        ],
      },
    );
    expect(a.hashCode, equals(b.hashCode));
  });

  test('hashCode differs when metadata differs', () {
    final a = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'key': 'value1'},
    );
    final b = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'key': 'value2'},
    );
    // hashCodes may collide, but they should usually differ
    expect(a.hashCode, isNot(equals(b.hashCode)));
  });

  test('hashCode handles null metadata', () {
    const a = ChatMessage(role: 'user', content: 'Hello');
    const b = ChatMessage(role: 'user', content: 'Hello');
    expect(a.hashCode, equals(b.hashCode));
  });
}

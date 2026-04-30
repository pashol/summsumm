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

  group('ChatSession comprehensive tests', () {
    test('createdAt and updatedAt UTC round-trip', () {
      final createdAt = DateTime(2025, 1, 15, 10, 30, 0).toUtc();
      final updatedAt = DateTime(2025, 1, 20, 14, 45, 30).toUtc();
      
      final session = ChatSession(
        id: 'date-test',
        title: 'Date Test',
        createdAt: createdAt,
        updatedAt: updatedAt,
        messages: [],
      );
      
      final json = session.toJson();
      final restored = ChatSession.fromJson(json);
      
      expect(restored.createdAt, equals(createdAt));
      expect(restored.updatedAt, equals(updatedAt));
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.updatedAt.isUtc, isTrue);
    });

    test('isArchived default value is false', () {
      final session = ChatSession(
        id: 'archive-test',
        title: 'Archive Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      
      expect(session.isArchived, isFalse);
    });

    test('isArchived deserialization', () {
      final json = {
        'id': 'archive-test',
        'title': 'Archive Test',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'messages': [],
        'isArchived': true,
      };
      
      final restored = ChatSession.fromJson(json);
      expect(restored.isArchived, isTrue);
    });

    test('toJsonString and fromJsonString round-trip', () {
      final session = ChatSession(
        id: 'string-test',
        title: 'String Test',
        createdAt: DateTime(2025, 3, 1, 8, 0, 0).toUtc(),
        updatedAt: DateTime(2025, 3, 2, 9, 0, 0).toUtc(),
        messages: [
          const ChatMessage(role: 'user', content: 'Test message'),
        ],
        isArchived: true,
      );
      
      final jsonString = session.toJsonString();
      final restored = ChatSession.fromJsonString(jsonString);
      
      expect(restored.id, 'string-test');
      expect(restored.title, 'String Test');
      expect(restored.createdAt, equals(session.createdAt));
      expect(restored.updatedAt, equals(session.updatedAt));
      expect(restored.messages.length, 1);
      expect(restored.messages[0].content, 'Test message');
      expect(restored.isArchived, isTrue);
    });

    test('copyWith changes fields correctly', () {
      final original = ChatSession(
        id: 'original',
        title: 'Original Title',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Original'),
        ],
        isArchived: false,
      );
      
      final newMessages = [
        const ChatMessage(role: 'user', content: 'New'),
        const ChatMessage(role: 'assistant', content: 'Response'),
      ];
      
      final copied = original.copyWith(
        title: 'New Title',
        messages: newMessages,
        isArchived: true,
      );
      
      // Unchanged fields
      expect(copied.id, 'original');
      expect(copied.createdAt, equals(original.createdAt));
      expect(copied.updatedAt, equals(original.updatedAt));
      
      // Changed fields
      expect(copied.title, 'New Title');
      expect(copied.messages, equals(newMessages));
      expect(copied.isArchived, isTrue);
    });

    test('copyWith preserves unchanged fields when null', () {
      final original = ChatSession(
        id: 'original',
        title: 'Original Title',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Original'),
        ],
        isArchived: false,
      );
      
      final copied = original.copyWith();
      
      expect(copied.id, original.id);
      expect(copied.title, original.title);
      expect(copied.createdAt, original.createdAt);
      expect(copied.updatedAt, original.updatedAt);
      expect(copied.messages, original.messages);
      expect(copied.isArchived, original.isArchived);
    });

    test('empty messages list edge case', () {
      final session = ChatSession(
        id: 'empty-test',
        title: 'Empty Messages',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messages: [],
      );
      
      final json = session.toJson();
      final restored = ChatSession.fromJson(json);
      
      expect(restored.messages, isEmpty);
      expect(restored.messages.length, 0);
    });

    test('== returns true for identical sessions', () {
      final a = ChatSession(
        id: 'eq-test',
        title: 'Equality Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Hello'),
          const ChatMessage(role: 'assistant', content: 'Hi'),
        ],
        isArchived: true,
      );
      final b = ChatSession(
        id: 'eq-test',
        title: 'Equality Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Hello'),
          const ChatMessage(role: 'assistant', content: 'Hi'),
        ],
        isArchived: true,
      );
      expect(a, equals(b));
      expect(a == b, isTrue);
    });

    test('== returns false when fields differ', () {
      final base = ChatSession(
        id: 'eq-test',
        title: 'Equality Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [],
        isArchived: false,
      );

      expect(base == base.copyWith(id: 'different'), isFalse);
      expect(base == base.copyWith(title: 'different'), isFalse);
      expect(base == base.copyWith(createdAt: DateTime(2025, 2, 1)), isFalse);
      expect(base == base.copyWith(updatedAt: DateTime(2025, 2, 2)), isFalse);
      expect(base == base.copyWith(isArchived: true), isFalse);
    });

    test('== returns false when messages differ', () {
      final a = ChatSession(
        id: 'msg-test',
        title: 'Messages Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messages: [const ChatMessage(role: 'user', content: 'A')],
      );
      final b = ChatSession(
        id: 'msg-test',
        title: 'Messages Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messages: [const ChatMessage(role: 'user', content: 'B')],
      );
      expect(a == b, isFalse);
    });

    test('hashCode is consistent for equal objects', () {
      final a = ChatSession(
        id: 'hash-test',
        title: 'Hash Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Hello'),
        ],
        isArchived: true,
      );
      final b = ChatSession(
        id: 'hash-test',
        title: 'Hash Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [
          const ChatMessage(role: 'user', content: 'Hello'),
        ],
        isArchived: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs when fields differ', () {
      final base = ChatSession(
        id: 'hash-test',
        title: 'Hash Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
        messages: [],
        isArchived: false,
      );

      expect(base.hashCode, isNot(equals(base.copyWith(id: 'different').hashCode)));
      expect(base.hashCode, isNot(equals(base.copyWith(title: 'different').hashCode)));
      expect(base.hashCode, isNot(equals(base.copyWith(isArchived: true).hashCode)));
    });
  });
}

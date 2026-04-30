import 'dart:convert';
import 'package:summsumm/models/chat_message.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool isArchived;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isArchived = false,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    bool? isArchived,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'messages': messages.map((m) => m.toApiMap()).toList(),
      'isArchived': isArchived,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      messages: messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatSession.fromJsonString(String s) =>
      ChatSession.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSession &&
        other.id == id &&
        other.title == title &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isArchived == isArchived &&
        _listEquals(other.messages, messages);
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        createdAt,
        updatedAt,
        isArchived,
        Object.hashAll(messages),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

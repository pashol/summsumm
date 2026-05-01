import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import 'chat_repository_provider.dart';

class AskLibrarySessionState {
  final String? id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AskLibrarySessionState({
    this.id,
    this.title = '',
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  AskLibrarySessionState copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AskLibrarySessionState(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AskLibrarySessionState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          messages == other.messages &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      messages.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}

class AskLibrarySessionNotifier extends StateNotifier<AskLibrarySessionState> {
  final Ref _ref;

  AskLibrarySessionNotifier(this._ref)
    : super(
        AskLibrarySessionState(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  void loadSession(ChatSession session) {
    state = AskLibrarySessionState(
      id: session.id,
      title: session.title,
      messages: List.of(session.messages),
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      updatedAt: DateTime.now(),
    );
  }

  void newSession() {
    state = AskLibrarySessionState(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveCurrentSession() async {
    if (state.messages.isEmpty) return;

    try {
      final title = state.title.isNotEmpty
          ? state.title
          : _generateTitle(state.messages);

      final session = ChatSession(
        id: state.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        createdAt: state.createdAt,
        updatedAt: DateTime.now(),
        messages: state.messages,
      );

      final repository = _ref.read(chatRepositoryProvider);
      await repository.save(session);

      // Update state with assigned ID if it was new
      if (state.id == null) {
        state = state.copyWith(id: session.id);
      }
    } catch (e) {
      debugPrint('Error saving current session: $e');
    }
  }

  String _generateTitle(List<ChatMessage> messages) {
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => const ChatMessage(role: 'user', content: 'New Chat'),
    );
    final content = firstUserMessage.content;
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }
}

final askLibrarySessionProvider =
    StateNotifierProvider<AskLibrarySessionNotifier, AskLibrarySessionState>(
      (ref) => AskLibrarySessionNotifier(ref),
    );

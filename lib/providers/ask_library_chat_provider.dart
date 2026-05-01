import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/library_rag.dart';
import '../providers/library_rag_provider.dart';
import '../providers/models_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../services/library_rag_service.dart';
import 'ask_library_chat_history_provider.dart';
import 'ask_library_session_provider.dart';

class AskLibraryChatState {
  final List<AskLibraryMessage> messages;
  final bool isStreaming;
  final String? error;

  const AskLibraryChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  AskLibraryChatState copyWith({
    List<AskLibraryMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) {
    return AskLibraryChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AskLibraryChatNotifier extends StateNotifier<AskLibraryChatState> {
  static const _maxPromptHistoryMessages = 6;
  static const _maxRetrievalHistoryMessages = 4;

  final Ref _ref;
  StreamSubscription<String>? _streamSub;
  bool _mounted = true;

  AskLibraryChatNotifier(this._ref) : super(const AskLibraryChatState());

  Future<void> newChat() async {
    _streamSub?.cancel();
    _streamSub = null;
    state = const AskLibraryChatState();
    await _ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
    _ref.read(askLibraryChatHistoryProvider.notifier).refresh();
    _ref.read(askLibrarySessionProvider.notifier).newSession();
  }

  Future<void> sendMessage(String question) async {
    final trimmed = question.trim();
    if (state.isStreaming || trimmed.isEmpty) return;

    final userMessage = AskLibraryMessage(role: 'user', content: trimmed);
    const assistantMessage = AskLibraryMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isStreaming: true,
      clearError: true,
    );

    try {
      final repository = _ref.read(libraryRagRepositoryProvider);
      final previousMessages = _previousMessagesExcludingPendingTurn();
      final search = await repository.search(
        _buildRetrievalQuery(previousMessages, trimmed),
      );
      if (search.contextText.trim().isEmpty) {
        final updated = List<AskLibraryMessage>.from(state.messages);
        updated[updated.length - 1] = const AskLibraryMessage(
          role: 'assistant',
          content:
              'I could not find enough relevant context in your library to answer that.',
        );
        state = state.copyWith(messages: updated, isStreaming: false);
        await _persistSession();
        return;
      }

      final citations = await _citationsForSearch(search);
      final settings = _ref.read(settingsProvider);
      final apiKey = await _ref
              .read(settingsProvider.notifier)
              .getApiKey(settings.provider) ??
          '';
      final apiMessages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content':
              'You answer questions using only the provided library context. If the context does not support an answer, say you could not find enough information. Keep answers concise and cite source labels when useful.',
        },
        {
          'role': 'system',
          'content': 'Library context for this turn:\n${search.contextText}',
        },
        ..._buildPromptHistory(previousMessages),
        {
          'role': 'user',
          'content': trimmed,
        },
      ];

      final stream = _ref.read(aiServiceProvider).streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: apiMessages,
            provider: settings.provider,
          );

      var accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<AskLibraryMessage>.from(state.messages);
          updated[updated.length - 1] = AskLibraryMessage(
            role: 'assistant',
            content: accumulated,
            citations: citations,
          );
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) => _handleError(e),
        onDone: () async {
          if (!_mounted) return;
          await _persistSession();
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!_mounted) return;
      _handleError(e);
    }
  }

  Future<List<LibraryCitation>> _citationsForSearch(
    LibraryRagSearchResult search,
  ) async {
    final seen = <String>{};
    final citations = <LibraryCitation>[];
    for (final chunk in search.chunks) {
      final metadataJson = chunk.metadata;
      if (metadataJson == null || metadataJson.isEmpty) continue;
      final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
      final id = decoded['libraryItemId'] as String?;
      if (id == null || !seen.add(id)) continue;
      citations.add(
        LibraryCitation(
          libraryItemId: id,
          title: decoded['title'] as String? ?? 'Untitled',
          sourceKind: LibrarySourceKind.values.byName(
            decoded['sourceKind'] as String,
          ),
          contentType: LibraryContentType.values.byName(
            decoded['contentType'] as String,
          ),
          excerpt: chunk.content,
        ),
      );
    }
    return citations;
  }

  void _handleError(Object e) {
    if (!_mounted) return;
    final updated = List<AskLibraryMessage>.from(state.messages)..removeLast();
    state = state.copyWith(
      messages: updated,
      isStreaming: false,
      error: e is AiException ? e.message : e.toString(),
    );
  }

  Future<void> _persistSession() async {
    final messages = state.messages;
    if (messages.length < 2) return;

    _ref.read(askLibrarySessionProvider.notifier).addMessage(
      _toChatMessage(messages[messages.length - 2]),
    );
    _ref.read(askLibrarySessionProvider.notifier).addMessage(
      _toChatMessage(messages.last),
    );
    await _ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
    _ref.read(askLibraryChatHistoryProvider.notifier).refresh();
  }

  ChatMessage _toChatMessage(AskLibraryMessage msg) => ChatMessage(
        role: msg.role,
        content: msg.content,
        metadata: msg.citations.isNotEmpty
            ? {'citations': msg.citations.map((c) => c.toJson()).toList()}
            : null,
      );

  List<AskLibraryMessage> _previousMessagesExcludingPendingTurn() {
    if (state.messages.length < 2) return const [];
    return state.messages.take(state.messages.length - 2).toList();
  }

  List<Map<String, dynamic>> _buildPromptHistory(
    List<AskLibraryMessage> messages,
  ) {
    final recentMessages = messages.length <= _maxPromptHistoryMessages
        ? messages
        : messages.sublist(messages.length - _maxPromptHistoryMessages);

    return recentMessages
        .map(
          (message) => {
            'role': message.role,
            'content': message.content,
          },
        )
        .toList();
  }

  String _buildRetrievalQuery(
    List<AskLibraryMessage> messages,
    String question,
  ) {
    final recentMessages = messages.length <= _maxRetrievalHistoryMessages
        ? messages
        : messages.sublist(messages.length - _maxRetrievalHistoryMessages);
    if (recentMessages.isEmpty) return question;

    final buffer = StringBuffer('Recent conversation:\n');
    for (final message in recentMessages) {
      final speaker = message.role == 'assistant' ? 'Assistant' : 'User';
      buffer.writeln('$speaker: ${message.content}');
    }
    buffer
      ..writeln()
      ..write('Current question: $question');
    return buffer.toString();
  }

  @override
  void dispose() {
    _mounted = false;
    _streamSub?.cancel();
    super.dispose();
  }
}

final askLibraryChatProvider =
    StateNotifierProvider<AskLibraryChatNotifier, AskLibraryChatState>(
  AskLibraryChatNotifier.new,
);

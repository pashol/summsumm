import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/library_rag_provider.dart';
import '../providers/local_llm_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

class MeetingChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? error;

  const MeetingChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  MeetingChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) =>
      MeetingChatState(
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        error: clearError ? null : (error ?? this.error),
      );
}

class MeetingChatNotifier extends StateNotifier<MeetingChatState> {
  final Ref _ref;
  StreamSubscription<String>? _streamSub;
  bool _mounted = true;

  MeetingChatNotifier(this._ref) : super(const MeetingChatState());

  String _truncateForLocalModel(String text, {required int maxChars}) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars - 3) + '...';
  }

  String _fullTranscriptPrompt(String transcript, String? summary, {bool isLocal = false}) {
    final effectiveTranscript = isLocal
        ? _truncateForLocalModel(transcript, maxChars: 2000)
        : transcript;
    final effectiveSummary = summary != null && isLocal
        ? _truncateForLocalModel(summary, maxChars: 500)
        : summary;
    return 'You are a helpful assistant. The user recorded a meeting.\n'
        'Transcript:\n$effectiveTranscript\n'
        '${effectiveSummary != null ? '\nSummary:\n$effectiveSummary\n' : ''}'
        '\nAnswer questions about this meeting concisely.';
  }

  Future<void> sendMessage(
    String question, {
    required String transcript,
    required String meetingId,
    String? summary,
  }) async {
    if (state.isStreaming || question.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: question.trim());
    const assistantMsg = ChatMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
      clearError: true,
    );

    final settings = _ref.read(settingsProvider);

    // Try RAG-first context
    String systemPrompt;
    final metadataStore = _ref.read(libraryRagMetadataStoreProvider);
    final metadata = await metadataStore.load();
    final indexedSource = metadata.sourceForLibraryItem(meetingId);

    if (indexedSource != null) {
      try {
        final ragService = _ref.read(libraryRagServiceProvider);
        final searchResult = await ragService.search(
          question,
          sourceIds: [indexedSource.ragSourceId],
        );
        if (searchResult.contextText.trim().isNotEmpty) {
          final contextText = settings.localAiEnabled
              ? _truncateForLocalModel(searchResult.contextText, maxChars: 2000)
              : searchResult.contextText;
          final summaryText = summary != null && settings.localAiEnabled
              ? _truncateForLocalModel(summary, maxChars: 500)
              : summary;
          systemPrompt =
              'You are a helpful assistant. The user recorded a meeting. '
              'Here is the most relevant context from the meeting:\n'
              '$contextText\n'
              '${summaryText != null ? '\nSummary:\n$summaryText\n' : ''}'
              '\nAnswer questions about this meeting concisely using the provided context.';
        } else {
          systemPrompt = _fullTranscriptPrompt(transcript, summary, isLocal: settings.localAiEnabled);
        }
      } catch (e, st) {
        debugPrint('RAG lookup failed for meeting $meetingId: $e\n$st');
        systemPrompt = _fullTranscriptPrompt(transcript, summary, isLocal: settings.localAiEnabled);
      }
    } else {
      systemPrompt = _fullTranscriptPrompt(transcript, summary, isLocal: settings.localAiEnabled);
    }

    final history = state.messages
        .take(state.messages.length - 1) // exclude the empty assistant msg
        .map((m) => m.toApiMap())
        .toList();

    late final Stream<String> stream;

    if (settings.localAiEnabled) {
      final localLlm = _ref.read(localLlmServiceProvider);
      final installed = await localLlm.isModelInstalled();
      if (!installed) {
        final msgs = List<ChatMessage>.from(state.messages)..removeLast();
        state = state.copyWith(
          messages: msgs,
          isStreaming: false,
          error: 'Local AI model not downloaded. Download it in Settings first.',
        );
        return;
      }
      await localLlm.ensureModelLoaded();

      stream = localLlm.streamChat(
        systemPrompt: systemPrompt,
        messages: history,
      );
    } else {
      final apiKey =
          await _ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
      if (apiKey.isEmpty) {
        final msgs = List<ChatMessage>.from(state.messages)..removeLast();
        state = state.copyWith(
          messages: msgs,
          isStreaming: false,
          error: 'No API key configured. Open Settings first.',
        );
        return;
      }

      final apiMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...history,
      ];

      stream = _ref.read(aiServiceProvider).streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: apiMessages,
            provider: settings.provider,
          );
    }

    try {
      String accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<ChatMessage>.from(state.messages);
          updated[updated.length - 1] =
              ChatMessage(role: 'assistant', content: accumulated);
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) {
          if (!_mounted) return;
          final msgs = List<ChatMessage>.from(state.messages)
            ..removeLast();
          final errorStr = e.toString();
          String friendlyError;
          if (errorStr.contains('OUT_OF_RANGE') && errorStr.contains('too long')) {
            friendlyError = 'The question and context are too long for the local model. Try a shorter question or use cloud AI instead.';
          } else if (errorStr.contains('maxTokens')) {
            friendlyError = 'Input is too long for the local model. Try a shorter question or use cloud AI instead.';
          } else {
            friendlyError = e is AiException ? e.message : e.toString();
          }
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: friendlyError,
          );
        },
        onDone: () {
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final msgs = List<ChatMessage>.from(state.messages)..removeLast();
      final errorStr = e.toString();
      String friendlyError;
      if (errorStr.contains('OUT_OF_RANGE') && errorStr.contains('too long')) {
        friendlyError = 'The question and context are too long for the local model. Try a shorter question or use cloud AI instead.';
      } else if (errorStr.contains('maxTokens')) {
        friendlyError = 'Input is too long for the local model. Try a shorter question or use cloud AI instead.';
      } else {
        friendlyError = e is AiException ? e.message : e.toString();
      }
      state = state.copyWith(
        messages: msgs,
        isStreaming: false,
        error: friendlyError,
      );
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> sendDocumentMessage(
    String question, {
    required String audioPath,
  }) async {
    if (state.isStreaming || question.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: question.trim());
    const assistantMsg = ChatMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
      clearError: true,
    );

    final settings = _ref.read(settingsProvider);
    final apiKey =
        await _ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
    final aiService = _ref.read(aiServiceProvider);

    final file = io.File(audioPath);
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    final fileContent = [
      {
        'type': 'file',
        'file': {
          'filename': 'document.pdf',
          'file_data': 'data:application/pdf;base64,$base64Data',
        },
      },
      {
        'type': 'text',
        'text': question.trim(),
      },
    ];

    final history = state.messages
        .take(state.messages.length - 1)
        .map((m) => m.toApiMap())
        .toList();

    final isFirstMessage = state.messages.length == 2;

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': 'You are a helpful assistant that answers questions about the provided document.'},
      if (isFirstMessage)
        {'role': 'user', 'content': fileContent}
      else
        ...history,
    ];

    try {
      final stream = aiService.streamCompletion(
        apiKey: apiKey,
        model: settings.activeModel,
        messages: apiMessages,
        provider: settings.provider,
      );

      String accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<ChatMessage>.from(state.messages);
          updated[updated.length - 1] =
              ChatMessage(role: 'assistant', content: accumulated);
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) {
          if (!_mounted) return;
          final msgs = List<ChatMessage>.from(state.messages)
            ..removeLast();
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: e is AiException ? e.message : e.toString(),
          );
        },
        onDone: () {
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final msgs = List<ChatMessage>.from(state.messages)..removeLast();
      state = state.copyWith(
        messages: msgs,
        isStreaming: false,
        error: e is AiException ? e.message : e.toString(),
      );
    }
  }
}

final meetingChatProvider =
    StateNotifierProvider.family<MeetingChatNotifier, MeetingChatState, String>(
  (ref, meetingId) => MeetingChatNotifier(ref),
);
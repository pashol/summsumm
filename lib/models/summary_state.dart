import 'package:flutter/foundation.dart';

import 'chat_message.dart';

enum SummaryStatus { idle, loading, streaming, done, error }

class SummaryState {
  final SummaryStatus status;
  final String summary;
  final String error;
  final List<ChatMessage> chat;
  final int followUpCount;
  final bool isSpeaking;
  final bool isCursorVisible;
  final String streamingReply;
  final TtsState ttsState;
  final bool isFactChecking;

  SummaryState({
    required this.status,
    required this.summary,
    required this.error,
    required List<ChatMessage> chat,
    required this.followUpCount,
    required this.isSpeaking,
    required this.isCursorVisible,
    required this.streamingReply,
    this.ttsState = TtsState.stopped,
    this.isFactChecking = false,
  }) : chat = List.unmodifiable(chat);

  factory SummaryState.initial() => SummaryState(
        status: SummaryStatus.idle,
        summary: '',
        error: '',
        chat: const [],
        followUpCount: 0,
        isSpeaking: false,
        isCursorVisible: true,
        streamingReply: '',
        ttsState: TtsState.stopped,
        isFactChecking: false,
      );

  SummaryState copyWith({
    SummaryStatus? status,
    String? summary,
    String? error,
    List<ChatMessage>? chat,
    int? followUpCount,
    bool? isSpeaking,
    bool? isCursorVisible,
    String? streamingReply,
    TtsState? ttsState,
    bool? isFactChecking,
  }) =>
      SummaryState(
        status: status ?? this.status,
        summary: summary ?? this.summary,
        error: error ?? this.error,
        chat: chat ?? this.chat,
        followUpCount: followUpCount ?? this.followUpCount,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        isCursorVisible: isCursorVisible ?? this.isCursorVisible,
        streamingReply: streamingReply ?? this.streamingReply,
        ttsState: ttsState ?? this.ttsState,
        isFactChecking: isFactChecking ?? this.isFactChecking,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryState &&
        other.status == status &&
        other.summary == summary &&
        other.error == error &&
        listEquals(other.chat, chat) &&
        other.followUpCount == followUpCount &&
        other.isSpeaking == isSpeaking &&
        other.isCursorVisible == isCursorVisible &&
        other.streamingReply == streamingReply &&
        other.ttsState == ttsState &&
        other.isFactChecking == isFactChecking;
  }

  @override
  int get hashCode => Object.hash(
        status,
        summary,
        error,
        Object.hashAll(chat),
        followUpCount,
        isSpeaking,
        isCursorVisible,
        streamingReply,
        ttsState,
        isFactChecking,
      );
}

enum TtsState { stopped, playing, paused }

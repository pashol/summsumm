import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/summary_state.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import 'models_provider.dart';

part 'summary_provider.g.dart';

const _maxInputChars = 10000;
const _maxFollowUps = 3;

String _langSuffix(String language, String subject) {
  if (language == 'English') return '';
  return '\n\nIMPORTANT: $subject must be in $language.';
}

@Riverpod(keepAlive: true)
class Summary extends _$Summary {
  final TtsService _tts = TtsService();
  Timer? _blinkTimer;
  StreamSubscription<String>? _streamSub;
  bool _mounted = true;

  @override
  SummaryState build() {
    _mounted = true;
    _tts.setOnCompletion(() {
      if (_mounted) {
        state = state.copyWith(
          isSpeaking: false,
          ttsState: TtsState.stopped,
        );
      }
    });
    _tts.setOnContinue(() {
      if (_mounted) state = state.copyWith(ttsState: TtsState.playing);
    });
    _tts.setOnPause(() {
      if (_mounted) state = state.copyWith(ttsState: TtsState.paused);
    });
    _tts.setOnError((msg) {
      if (_mounted) {
        state = state.copyWith(
          isSpeaking: false,
          ttsState: TtsState.stopped,
        );
      }
    });
    ref.onDispose(() async {
      _mounted = false;
      _cancelStream();
      _stopBlink();
      await _tts.stop();
    });
    return SummaryState.initial();
  }

  Future<void> summarize({
    required String inputText,
    required String apiKey,
    required AppSettings settings,
  }) async {
    _cancelStream();
    _stopBlink();
    await _tts.stop();
    state = SummaryState.initial().copyWith(
      status: SummaryStatus.loading,
      ttsState: TtsState.stopped,
    );

    final trimmed = inputText.length > _maxInputChars
        ? inputText.substring(0, _maxInputChars)
        : inputText;

    final langSuffix = _langSuffix(settings.language, 'Summary');

    final messages = [
      {
        'role': 'system',
        'content':
            'You are a helpful assistant that summarizes text concisely.',
      },
      {
        'role': 'user',
        'content':
            'Concise plain text summary (no markdown) of the following text. '
                '$langSuffix\n\nText:\n$trimmed',
      },
    ];

    _startBlink();
    state = state.copyWith(status: SummaryStatus.streaming, summary: '');

    try {
      _streamSub = ref
          .read(aiServiceProvider)
          .streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: messages,
            provider: settings.provider,
          )
          .listen(
        (delta) {
          if (_mounted) state = state.copyWith(summary: state.summary + delta);
        },
        onError: (Object e) {
          _stopBlink();
          if (_mounted) {
            state = state.copyWith(
              status: SummaryStatus.error,
              error: e.toString(),
            );
          }
        },
        onDone: () {
          _stopBlink();
          if (_mounted) {
            state = state.copyWith(
              status: SummaryStatus.done,
              isCursorVisible: false,
            );
          }
        },
        cancelOnError: true,
      );
    } on AiException catch (e) {
      _stopBlink();
      state = state.copyWith(
        status: SummaryStatus.error,
        error: e.message,
      );
    } catch (e) {
      _stopBlink();
      state = state.copyWith(
        status: SummaryStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> askFollowUp({
    required String question,
    required String originalText,
    required String apiKey,
    required AppSettings settings,
  }) async {
    if (state.followUpCount >= _maxFollowUps) return;
    if (state.status == SummaryStatus.streaming) return;

    _cancelStream();
    _stopBlink();
    await _tts.stop();

    final userMsg = ChatMessage(role: 'user', content: question);
    state = state.copyWith(
      chat: [...state.chat, userMsg],
      streamingReply: '',
      status: SummaryStatus.streaming,
      ttsState: TtsState.stopped,
      isSpeaking: false,
    );

    final trimmedOriginal = originalText.length > _maxInputChars
        ? originalText.substring(0, _maxInputChars)
        : originalText;

    final langSuffix = _langSuffix(settings.language, 'Your entire response');

    final systemPrompt =
        'You are an AI assistant helping a user understand a text.\n'
        '\n'
        'You previously generated this summary:\n'
        '${state.summary}\n'
        '\n'
        'Answer follow-up questions based on the text above. '
        'Be concise and accurate. Plain text only, no markdown. '
        'If the answer is in the text, refer to it specifically. '
        'If it is not, answer from your general knowledge and note that '
        'the text does not cover this.'
        '$langSuffix';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': trimmedOriginal},
      {'role': 'assistant', 'content': state.summary},
      ...state.chat.take(state.chat.length - 1).map((m) => m.toApiMap()),
      userMsg.toApiMap(),
    ];

    _startBlink();

    try {
      _streamSub = ref
          .read(aiServiceProvider)
          .streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: messages,
            provider: settings.provider,
          )
          .listen(
        (delta) {
          if (_mounted) {
            state =
                state.copyWith(streamingReply: state.streamingReply + delta);
          }
        },
        onError: (Object e) {
          _stopBlink();
          _finaliseFollowUp();
          if (_mounted) {
            state = state.copyWith(
              status: SummaryStatus.error,
              error: e.toString(),
            );
          }
        },
        onDone: () {
          _stopBlink();
          _finaliseFollowUp();
        },
        cancelOnError: true,
      );
    } on AiException catch (e) {
      _stopBlink();
      state = state.copyWith(
        status: SummaryStatus.error,
        error: e.message,
      );
    }
  }

  void _finaliseFollowUp() {
    final assistantMsg =
        ChatMessage(role: 'assistant', content: state.streamingReply);
    state = state.copyWith(
      chat: [...state.chat, assistantMsg],
      streamingReply: '',
      followUpCount: state.followUpCount + 1,
      status: SummaryStatus.done,
      isCursorVisible: false,
    );
  }

  Future<void> factCheck({
    required String inputText,
    required String apiKey,
    required AppSettings settings,
  }) async {
    _cancelStream();
    _stopBlink();
    await _tts.stop();

    const maxFactCheckChars = 10000;
    final trimmed = inputText.length > maxFactCheckChars
        ? inputText.substring(0, maxFactCheckChars)
        : inputText;

    final langSuffix = _langSuffix(settings.language, 'Your entire response');

    final messages = [
      {
        'role': 'system',
        'content':
            'You are a critical investigative journalist. Verify the factual claims in the following content with rigorous skepticism.',
      },
      {
        'role': 'user',
        'content': 'Analyze the content and identify the 5-8 most significant factual claims. '
            'For each claim, determine if it is TRUE, FALSE, or UNVERIFIED based on your knowledge.\n'
            '\n'
            'Respond in EXACTLY this plain text format (no markdown, no asterisks):\n'
            '\n'
            'Overall: [one sentence summarizing the overall credibility of this content]\n'
            '\n'
            '✅ TRUE (1): [specific claim] → [brief explanation of why it is true]\n'
            '❌ FALSE (2): [specific claim] → [brief explanation of what is actually true]\n'
            '⚠️ UNVERIFIED (3): [specific claim] → [brief explanation of why this is hard to verify]\n'
            '\n'
            'Use the exact emoji prefixes shown. Number each claim sequentially across all categories. '
            'Do not include external links or URLs.'
            '$langSuffix\n\nContent:\n$trimmed',
      },
    ];

    _startBlink();
    state = SummaryState.initial().copyWith(
      status: SummaryStatus.streaming,
      summary: '',
      isFactChecking: true,
    );

    try {
      _streamSub = ref
          .read(aiServiceProvider)
          .streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: messages,
            provider: settings.provider,
          )
          .listen(
        (delta) {
          if (_mounted) state = state.copyWith(summary: state.summary + delta);
        },
        onError: (Object e) {
          _stopBlink();
          if (_mounted) {
            state = state.copyWith(
              status: SummaryStatus.error,
              error: e.toString(),
            );
          }
        },
        onDone: () {
          _stopBlink();
          if (_mounted) {
            state = state.copyWith(
              status: SummaryStatus.done,
              isCursorVisible: false,
              isFactChecking: true,
            );
          }
        },
        cancelOnError: true,
      );
    } on AiException catch (e) {
      _stopBlink();
      state = state.copyWith(
        status: SummaryStatus.error,
        error: e.message,
      );
    } catch (e) {
      _stopBlink();
      state = state.copyWith(
        status: SummaryStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> reset() async {
    _cancelStream();
    _stopBlink();
    await _tts.stop();
    state = SummaryState.initial();
  }

  Future<void> startSpeaking(String text, AppSettings settings) async {
    await _tts.stop();
    await _tts.speak(
      text,
      kLanguageTtsCode[settings.language] ?? 'en-US',
      settings.ttsSpeed,
    );
    state = state.copyWith(isSpeaking: true, ttsState: TtsState.playing);
  }

  Future<void> pauseSpeaking() async {
    await _tts.pause();
    state = state.copyWith(ttsState: TtsState.paused);
  }

  Future<void> resumeSpeaking() async {
    await _tts.resume();
    state = state.copyWith(ttsState: TtsState.playing);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (_mounted) {
      state = state.copyWith(isSpeaking: false, ttsState: TtsState.stopped);
    }
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_mounted) {
        state = state.copyWith(isCursorVisible: !state.isCursorVisible);
      }
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void _cancelStream() {
    _streamSub?.cancel();
    _streamSub = null;
  }
}

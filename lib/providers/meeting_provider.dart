import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/services/voice_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());

final meetingProvider = NotifierProvider.family<MeetingNotifier, Meeting, String>(
  MeetingNotifier.new,
);

class MeetingNotifier extends FamilyNotifier<Meeting, String> {
  DateTime? _lastSave;

  @override
  Meeting build(String meetingId) {
    ref.listen(meetingLibraryProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });
    ref.listen(archivedMeetingsProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });

    final library = ref.read(meetingLibraryProvider);
    final archived = ref.read(archivedMeetingsProvider);
    return _findIn(library, meetingId) ??
        _findIn(archived, meetingId) ??
        _placeholder(meetingId);
  }

  Meeting? _findIn(AsyncValue<List<Meeting>> value, String meetingId) {
    return value.whenOrNull(
      data: (meetings) {
        try {
          return meetings.firstWhere((m) => m.id == meetingId);
        } catch (_) {
          return null;
        }
      },
    );
  }

  Meeting _placeholder(String meetingId) => Meeting(
        id: meetingId,
        createdAt: DateTime.now(),
        durationSec: 0,
        audioPath: '',
        title: '',
        status: MeetingStatus.recorded,
      );

  bool get _isPlaceholder => state.title.isEmpty && state.audioPath.isEmpty;

  Future<bool> _hasConnectivity(String provider) async {
    final url = provider == 'openai'
        ? Uri.parse('https://api.openai.com')
        : Uri.parse('https://openrouter.ai');
    try {
      final client = http.Client();
      try {
        final response = await client.head(url).timeout(const Duration(seconds: 5));
        return response.statusCode < 500;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  void _throttledSave(Meeting meeting) {
    final now = DateTime.now();
    if (_lastSave == null || now.difference(_lastSave!).inMilliseconds > 500) {
      _lastSave = now;
      final repository = ref.read(meetingRepositoryProvider);
      repository.save(meeting);
      ref.read(meetingLibraryProvider.notifier).refresh();
    }
  }

  Future<void> transcribe({bool diarize = false}) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final voiceService = ref.read(voiceServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(status: MeetingStatus.transcribing, clearLastError: true, transcriptionStatus: 'Validating audio…', transcriptionProgress: null);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final apiKey = await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
      final transcript = await voiceService.transcribeFile(
        meeting.audioPath,
        settings.provider,
        apiKey,
        diarize: diarize,
        onProgress: (status, progress) {
          final determinate = progress != null && progress >= 0.3;
          state = state.copyWith(
            transcriptionStatus: status,
            transcriptionProgress: determinate ? progress : null,
          );
          _throttledSave(state);
        },
      );

      state = state.copyWith(
        transcript: transcript,
        status: MeetingStatus.transcribed,
        provider: settings.provider,
        clearLastError: true,
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      rethrow;
    }
  }

  Future<void> summarize() async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(status: MeetingStatus.summarizing, clearLastError: true);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      String summary = '';

      if (meeting.type == MeetingType.document) {
        final file = io.File(meeting.audioPath);
        final summaryStream = aiService.streamCompletionWithFile(
          file: file,
          model: settings.activeModel,
          prompt: 'Summarize this document concisely.',
          provider: settings.provider,
          apiKey: await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '',
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          state = state.copyWith(summary: summary);
        }
      } else {
        final summaryStream = aiService.streamCompletion(
          model: settings.activeModel,
          messages: [
            {
              'role': 'system',
              'content': _meetingSummaryPrompt,
            },
            {
              'role': 'user',
              'content': meeting.transcript ?? '',
            },
          ],
          apiKey: await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '',
          provider: settings.provider,
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          state = state.copyWith(summary: summary);
        }
      }

      state = state.copyWith(
        status: MeetingStatus.done,
        clearLastError: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      rethrow;
    }
  }

  Future<void> retry() async {
    final meeting = state;
    if (meeting.status == MeetingStatus.failed) {
      if (meeting.transcript == null) {
        await transcribe();
      } else if (meeting.summary == null) {
        await summarize();
      }
    }
  }

  Future<void> rename(String newTitle) async {
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(title: newTitle);
    await repository.save(state);
  }

  Future<void> delete() async {
    final repository = ref.read(meetingRepositoryProvider);
    await repository.delete(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
  }

  Future<void> archive() async {
    if (_isPlaceholder) return;
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(archived: true);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    ref.read(archivedMeetingsProvider.notifier).refresh();
  }

  Future<void> unarchive() async {
    if (_isPlaceholder) return;
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(archived: false);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    ref.read(archivedMeetingsProvider.notifier).refresh();
  }
}

const _meetingSummaryPrompt = '''
You are an expert meeting summarizer. Extract:
1. Key decisions made
2. Action items with owners
3. Open questions
4. Important context

Use markdown headers and bullet points. Do not wrap output in a code block. Be concise and factual.
''';
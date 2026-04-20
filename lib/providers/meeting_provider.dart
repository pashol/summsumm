import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  Meeting build(String meetingId) {
    // Listen for changes and update state in-place without rebuilding
    ref.listen(meetingLibraryProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });
    ref.listen(archivedMeetingsProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });

    // Get initial value without subscribing to rebuilds
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

  Future<void> transcribe({bool diarize = false}) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final voiceService = ref.read(voiceServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    state = meeting.copyWith(status: MeetingStatus.transcribing, clearLastError: true, transcriptionStatus: 'Initializing');
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final apiKey = await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
      final transcript = await voiceService.transcribeFile(
        meeting.audioPath,
        settings.provider,
        apiKey,
        diarize: diarize,
        onProgress: (status, _) {
          state = state.copyWith(transcriptionStatus: _summarizeStatus(status));
        },
      );

      state = meeting.copyWith(
        transcript: transcript,
        status: MeetingStatus.transcribed,
        provider: settings.provider,
        clearLastError: true,
        clearTranscriptionStatus: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
        clearTranscriptionStatus: true,
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

    state = meeting.copyWith(status: MeetingStatus.summarizing, clearLastError: true);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      String summary;

      if (meeting.type == MeetingType.document) {
        final file = io.File(meeting.audioPath);
        final summaryStream = aiService.streamCompletionWithFile(
          file: file,
          model: settings.activeModel,
          prompt: 'Summarize this document concisely.',
          provider: settings.provider,
          apiKey: await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '',
        );
        summary = (await summaryStream.toList()).join();
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
        summary = (await summaryStream.toList()).join();
      }

      state = meeting.copyWith(
        summary: summary,
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

String _summarizeStatus(String status) {
  if (status.contains('Preprocessing')) return 'Preprocessing';
  if (status.contains('Analyzing')) return 'Analyzing';
  if (status.contains('Preparing')) return 'Preparing';
  if (status.contains('Transcribing')) return 'Transcribing';
  if (status.contains('Finalizing')) return 'Finalizing';
  return 'Processing';
}
import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';
import 'package:summsumm/services/processing_service.dart';
import 'package:summsumm/services/voice_service.dart';
import 'package:summsumm/providers/on_device_transcription_provider.dart';
import '../models/custom_prompt.dart';
import '../utils/prompt_resolver.dart';
import 'package:collection/collection.dart';

List<SpeakerSegment> _alignTranscriptToSegments(
  String transcript,
  List<SpeakerSegment> segments,
) {
  if (transcript.isEmpty || segments.isEmpty) return segments;

  final words = transcript
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return segments;

  final totalDuration = segments.fold<double>(
    0.0,
    (sum, s) => sum + (s.endTime - s.startTime),
  );
  if (totalDuration <= 0) return segments;

  int wordIdx = 0;
  return segments.map((seg) {
    final segDuration = seg.endTime - seg.startTime;
    final wordCount = (words.length * segDuration / totalDuration)
        .round()
        .clamp(0, words.length - wordIdx);
    final segText = words.sublist(wordIdx, wordIdx + wordCount).join(' ');
    wordIdx += wordCount;
    return SpeakerSegment(
      speakerLabel: seg.speakerLabel,
      startTime: seg.startTime,
      endTime: seg.endTime,
      text: segText,
    );
  }).toList();
}

const _diarizationFailurePrefix = 'Speaker diarization failed: ';

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());
final processingServiceProvider = Provider<ProcessingService>(
  (ref) => ProcessingService(),
);

final meetingProvider =
    NotifierProvider.family<MeetingNotifier, Meeting, String>(
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

  bool _isFailedOnDeviceDiarization(Meeting meeting) {
    return meeting.provider == 'on-device' &&
        meeting.transcript != null &&
        meeting.lastError?.startsWith(_diarizationFailurePrefix) == true;
  }

  Future<void> _applyOnDeviceDiarization({
    required Meeting meeting,
    required String transcript,
    required OnDeviceTranscriptionService service,
    required dynamic repository,
  }) async {
    state = state.copyWith(
      status: MeetingStatus.transcribing,
      transcriptionStatus: 'Identifying speakers…',
      transcriptionProgress: null,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final segments = await service.diarizeFile(meeting.audioPath);
      final aligned = _alignTranscriptToSegments(transcript, segments);
      state = state.copyWith(
        speakerSegments: aligned,
        status: MeetingStatus.transcribed,
        provider: 'on-device',
        clearLastError: true,
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: MeetingStatus.failed,
        lastError: '$_diarizationFailurePrefix$e',
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
    }

    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
  }

  Future<void> _retryOnDeviceDiarization(Meeting meeting) async {
    final transcript = meeting.transcript;
    if (transcript == null || transcript.isEmpty) {
      await transcribe();
      return;
    }

    final repository = ref.read(meetingRepositoryProvider);
    final service = ref.read(onDeviceTranscriptionServiceProvider);
    final processingService = ref.read(processingServiceProvider);

    try {
      await processingService.start();
      await _applyOnDeviceDiarization(
        meeting: meeting,
        transcript: transcript,
        service: service,
        repository: repository,
      );
    } finally {
      await processingService.stop();
    }
  }

  Future<bool> _hasConnectivity(String provider) async {
    final url = provider == 'openai'
        ? Uri.parse('https://api.openai.com')
        : Uri.parse('https://openrouter.ai');
    try {
      final client = http.Client();
      try {
        final response = await client
            .head(url)
            .timeout(const Duration(seconds: 5));
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
    final repository = ref.read(meetingRepositoryProvider);

    // Check if audio file exists
    if (!await io.File(meeting.audioPath).exists()) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'Audio file not found: ${meeting.audioPath}',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    // Check if using on-device transcription
    if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice) {
      await _transcribeOnDevice(diarize: diarize);
      return;
    }

    final voiceService = ref.read(voiceServiceProvider);
    final processingService = ref.read(processingServiceProvider);

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError:
            'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(
      status: MeetingStatus.transcribing,
      clearLastError: true,
      transcriptionStatus: 'Validating audio…',
      transcriptionProgress: null,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      await processingService.start();
      final apiKey =
          await ref
              .read(settingsProvider.notifier)
              .getApiKey(settings.provider) ??
          '';
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

      if (transcript == null || transcript.trim().isEmpty) {
        state = meeting.copyWith(
          status: MeetingStatus.failed,
          lastError:
              'Transcription returned no text. Please ensure the audio file is valid.',
        );
        await repository.save(state);
        ref.read(meetingLibraryProvider.notifier).refresh();
        return;
      }

      state = meeting.copyWith(
        rawTranscript: transcript,
        status: MeetingStatus.transcribed,
        provider: settings.provider,
        cleanupEnabled: true,
        clearLastError: true,
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();

      if (state.cleanupEnabled && state.rawTranscript != null) {
        state = state.copyWith(
          status: MeetingStatus.transcribing,
          transcriptionStatus: 'Cleaning up transcript…',
        );
        await repository.save(state);
        ref.read(meetingLibraryProvider.notifier).refresh();

        try {
          final aiService = ref.read(aiServiceProvider);
          final cleaned = StringBuffer();
          final cleanupStream = aiService.cleanupTranscript(
            rawTranscript: state.rawTranscript!,
            provider: settings.provider,
            apiKey: apiKey,
            model: settings.activeModel,
            diarized: diarize,
          );

          await for (final chunk in cleanupStream) {
            cleaned.write(chunk);
            state = state.copyWith(
              transcriptionStatus: 'Cleaning up transcript…',
            );
            _throttledSave(state);
          }

          state = state.copyWith(
            cleanedTranscript: cleaned.toString(),
            status: MeetingStatus.transcribed,
            clearTranscriptionStatus: true,
            clearTranscriptionProgress: true,
          );
        } catch (e) {
          state = state.copyWith(
            status: MeetingStatus.transcribed,
            clearTranscriptionStatus: true,
            clearTranscriptionProgress: true,
          );
        }
      }

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
    } finally {
      await processingService.stop();
    }
  }

  Future<void> _transcribeOnDevice({bool diarize = false}) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final repository = ref.read(meetingRepositoryProvider);
    final service = ref.read(onDeviceTranscriptionServiceProvider);
    final processingService = ref.read(processingServiceProvider);

    // Skip transcription if already live-transcribed
    if (meeting.wasLiveTranscribed) {
      // Only do diarization if needed
      if (diarize && settings.onDeviceDiarization) {
        final transcript = meeting.transcript;
        if (transcript == null || transcript.isEmpty) {
          state = meeting.copyWith(
            status: MeetingStatus.failed,
            lastError: 'Transcript not available for speaker diarization.',
            clearTranscriptionStatus: true,
            clearTranscriptionProgress: true,
          );
          await repository.save(state);
          ref.read(meetingLibraryProvider.notifier).refresh();
        } else {
          await _applyOnDeviceDiarization(
            meeting: meeting,
            transcript: transcript,
            service: service,
            repository: repository,
          );
        }
      } else {
        state = meeting.copyWith(
          status: MeetingStatus.transcribed,
          provider: 'on-device',
        );
        await repository.save(state);
        ref.read(meetingLibraryProvider.notifier).refresh();
      }
      return;
    }

    state = meeting.copyWith(
      status: MeetingStatus.transcribing,
      clearLastError: true,
      transcriptionStatus: 'Loading models…',
      transcriptionProgress: null,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      await processingService.start();

      // Initialize service
      state = state.copyWith(
        transcriptionStatus: 'Preparing on-device model…',
        transcriptionProgress: null,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();

      await service
          .initialize(settings.onDeviceModelSize)
          .timeout(const Duration(minutes: 3));

      // Transcribe
      state = state.copyWith(
        transcriptionStatus: 'Preparing audio…',
        transcriptionProgress: null,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();

      final transcript = await service.transcribeFile(
        meeting.audioPath,
        diarize: diarize && settings.onDeviceDiarization,
        onProgress: (status, progress) {
          state = state.copyWith(
            transcriptionStatus: status,
            transcriptionProgress: progress,
          );
          _throttledSave(state);
        },
      );

      if (transcript.isEmpty) {
        state = meeting.copyWith(
          status: MeetingStatus.failed,
          lastError:
              'Transcription returned no text. Please ensure the audio file is valid.',
        );
        await repository.save(state);
        ref.read(meetingLibraryProvider.notifier).refresh();
        return;
      }

      state = meeting.copyWith(
        rawTranscript: transcript,
        status: MeetingStatus.transcribed,
        provider: 'on-device',
        cleanupEnabled: true,
        clearSpeakerSegments: true,
        clearLastError: true,
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();

      if (diarize && settings.onDeviceDiarization) {
        await _applyOnDeviceDiarization(
          meeting: meeting,
          transcript: transcript,
          service: service,
          repository: repository,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      rethrow;
    } finally {
      await processingService.stop();
    }
  }

  Future<void> summarize({
    SummaryStyle? style,
    String? language,
    String? customPromptId,
  }) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    // Check if source file exists for documents
    if (meeting.type == MeetingType.document &&
        !await io.File(meeting.audioPath).exists()) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'Source file not found: ${meeting.audioPath}',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    final resolvedStyle =
        style ?? _resolveStyle(settings.summaryStyle, meeting.type);
    final resolvedLanguage = language ?? settings.language;

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError:
            'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(
      status: MeetingStatus.summarizing,
      clearLastError: true,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final langSuffixText = langSuffix(resolvedLanguage, 'The summary');
      final systemPrompt = _promptForStyle(
        resolvedStyle,
        meeting.type,
        langSuffixText,
        customPromptId: customPromptId,
      );

      String summary = '';
      final newSummary = MeetingSummary(
        id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
        style: resolvedStyle,
        language: resolvedLanguage,
        content: '',
        createdAt: DateTime.now(),
        customPromptId: customPromptId,
      );

      if (meeting.type == MeetingType.document) {
        final file = io.File(meeting.audioPath);
        final summaryStream = aiService.streamCompletionWithFile(
          file: file,
          model: settings.activeModel,
          prompt: systemPrompt,
          provider: settings.provider,
          apiKey:
              await ref
                  .read(settingsProvider.notifier)
                  .getApiKey(settings.provider) ??
              '',
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          final updated = newSummary.copyWith(content: summary);
          state = state.copyWith(summaries: [...meeting.summaries, updated]);
        }
      } else {
        final summaryStream = aiService.streamCompletion(
          model: settings.activeModel,
          messages: [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': meeting.transcript ?? ''},
          ],
          apiKey:
              await ref
                  .read(settingsProvider.notifier)
                  .getApiKey(settings.provider) ??
              '',
          provider: settings.provider,
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          final updated = newSummary.copyWith(content: summary);
          state = state.copyWith(summaries: [...meeting.summaries, updated]);
        }
      }

      if (summary.trim().isEmpty) {
        throw const AiException(
          'Summary failed: the provider returned an empty response.',
        );
      }

      state = state.copyWith(status: MeetingStatus.done, clearLastError: true);
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

  SummaryStyle _resolveStyle(String settingsStyle, MeetingType type) {
    final parsed = SummaryStyle.values.firstWhere(
      (s) => s.name == settingsStyle,
      orElse: () => SummaryStyle.structured,
    );
    final available = SummaryStyle.forType(type);
    if (available.contains(parsed)) return parsed;
    return available.first;
  }

  String _promptForStyle(
    SummaryStyle style,
    MeetingType type,
    String langSuffixText, {
    String? customPromptId,
  }) {
    final settings = ref.read(settingsProvider);

    // Check if a custom prompt is selected (either passed in or from settings)
    CustomPrompt? selectedCustom;
    final effectiveCustomPromptId =
        customPromptId ?? settings.selectedCustomPromptId;
    if (effectiveCustomPromptId != null) {
      selectedCustom = settings.customPrompts.firstWhereOrNull(
        (p) => p.id == effectiveCustomPromptId,
      );
    }

    final basePrompt = PromptResolver.resolve(
      style: style,
      customPrompt: selectedCustom,
      settings: settings,
    );

    return '$basePrompt$langSuffixText';
  }

  Future<void> retry() async {
    final meeting = state;
    if (meeting.status == MeetingStatus.failed) {
      if (_isFailedOnDeviceDiarization(meeting)) {
        await _retryOnDeviceDiarization(meeting);
      } else if (meeting.transcript == null) {
        await transcribe();
      } else if (meeting.summaries.isEmpty) {
        await summarize();
      }
    }
  }

  Future<void> resetTranscription() async {
    if (_isPlaceholder) return;
    final meeting = state;
    final repository = ref.read(meetingRepositoryProvider);

    state = meeting.copyWith(
      clearRawTranscript: true,
      clearCleanedTranscript: true,
      clearSpeakerSegments: true,
      clearTranscriptionLog: true,
      summaries: [],
      status: MeetingStatus.recorded,
      clearLastError: true,
      clearTranscriptionStatus: true,
      clearTranscriptionProgress: true,
      clearProvider: true,
      wasLiveTranscribed: false,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    ref.read(archivedMeetingsProvider.notifier).refresh();
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

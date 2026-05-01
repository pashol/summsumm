import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_provider.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/on_device_transcription_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';
import 'package:summsumm/services/processing_service.dart';

void main() {
  group('SummaryStyle', () {
    test('displayName returns correct labels', () {
      expect(SummaryStyle.concise.displayName, 'Concise');
      expect(SummaryStyle.brief.displayName, 'Brief');
      expect(SummaryStyle.detailed.displayName, 'Detailed');
      expect(SummaryStyle.structured.displayName, 'Structured');
    });

    test('forType returns correct styles for meetings', () {
      final styles = SummaryStyle.forType(MeetingType.meeting);
      expect(styles, [SummaryStyle.concise, SummaryStyle.detailed, SummaryStyle.structured]);
      expect(styles, isNot(contains(SummaryStyle.brief)));
    });

    test('forType returns correct styles for documents', () {
      final styles = SummaryStyle.forType(MeetingType.document);
      expect(styles, [SummaryStyle.concise, SummaryStyle.brief, SummaryStyle.detailed]);
      expect(styles, isNot(contains(SummaryStyle.structured)));
    });
  });

  group('langSuffix', () {
    test('returns suffix for Same as input', () {
      final result = langSuffix('Same as input', 'Summary');
      expect(result, contains('same language'));
      expect(result, contains('IMPORTANT'));
    });

    test('returns suffix for other languages', () {
      final result = langSuffix('German', 'Summary');
      expect(result, contains('German'));
      expect(result, contains('IMPORTANT'));
    });
  });

  group('MeetingNotifier offline diarization', () {
    late File audioFile;

    setUp(() async {
      audioFile = await File(
        '${Directory.systemTemp.path}/summsumm-meeting-provider-test.m4a',
      ).create(recursive: true);
      await audioFile.writeAsString('audio');
    });

    tearDown(() async {
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    });

    test('diarization failure marks meeting failed and preserves transcript', () async {
      final meeting = Meeting(
        id: 'meeting-1',
        createdAt: DateTime.utc(2026, 5, 1),
        durationSec: 60,
        audioPath: audioFile.path,
        title: 'Offline Meeting',
        status: MeetingStatus.recorded,
      );
      final repository = _MemoryMeetingRepository(meeting);
      final service = _FakeOnDeviceTranscriptionService(
        transcript: 'Transcript text',
        diarizeError: StateError('sample rate mismatch'),
      );
      final container = ProviderContainer(
        overrides: [
          meetingRepositoryProvider.overrideWithValue(repository),
          onDeviceTranscriptionServiceProvider.overrideWithValue(service),
          processingServiceProvider.overrideWithValue(_FakeProcessingService()),
          settingsProvider.overrideWith(_OnDeviceSettings.new),
          meetingLibraryProvider.overrideWith(() => _LoadedMeetingLibrary(repository)),
          archivedMeetingsProvider.overrideWith(_NoArchivedMeetings.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(meetingLibraryProvider.future);
      await container.read(archivedMeetingsProvider.future);

      await container.read(meetingProvider(meeting.id).notifier).transcribe(diarize: true);

      final updated = container.read(meetingProvider(meeting.id));
      expect(updated.rawTranscript, 'Transcript text');
      expect(updated.status, MeetingStatus.failed);
      expect(updated.lastError, contains('Speaker diarization failed:'));
      expect(updated.lastError, contains('sample rate mismatch'));
      expect(updated.transcriptionStatus, isNull);
      expect(updated.transcriptionProgress, isNull);
    });

    test('retry reruns diarization instead of summarizing completed transcript', () async {
      final meeting = Meeting(
        id: 'meeting-2',
        createdAt: DateTime.utc(2026, 5, 1),
        durationSec: 60,
        audioPath: audioFile.path,
        title: 'Offline Meeting',
        rawTranscript: 'Transcript text',
        status: MeetingStatus.failed,
        provider: 'on-device',
        lastError: 'Speaker diarization failed: sample rate mismatch',
      );
      final repository = _MemoryMeetingRepository(meeting);
      final service = _FakeOnDeviceTranscriptionService(
        transcript: 'unused',
        diarizeSegments: const [
          SpeakerSegment(
            speakerLabel: 'Speaker 1',
            startTime: 0,
            endTime: 1,
            text: '',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          meetingRepositoryProvider.overrideWithValue(repository),
          onDeviceTranscriptionServiceProvider.overrideWithValue(service),
          processingServiceProvider.overrideWithValue(_FakeProcessingService()),
          settingsProvider.overrideWith(_OnDeviceSettings.new),
          meetingLibraryProvider.overrideWith(() => _LoadedMeetingLibrary(repository)),
          archivedMeetingsProvider.overrideWith(_NoArchivedMeetings.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(meetingLibraryProvider.future);
      await container.read(archivedMeetingsProvider.future);

      await container.read(meetingProvider(meeting.id).notifier).retry();

      final updated = container.read(meetingProvider(meeting.id));
      expect(service.transcribeCalls, 0);
      expect(service.diarizeCalls, 1);
      expect(updated.status, MeetingStatus.transcribed);
      expect(updated.speakerSegments, isNotNull);
      expect(updated.speakerSegments!.single.text, 'Transcript text');
      expect(updated.lastError, isNull);
    });
  });
}

class _OnDeviceSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults().copyWith(
    transcriptionStrategy: TranscriptionStrategy.onDevice,
    onDeviceDiarization: true,
  );
}

class _LoadedMeetingLibrary extends MeetingLibraryNotifier {
  _LoadedMeetingLibrary(this.repository);

  final _MemoryMeetingRepository repository;

  @override
  Future<List<Meeting>> build() async => [repository.current];

  @override
  Future<void> refresh() async {
    state = AsyncData([repository.current]);
  }
}

class _NoArchivedMeetings extends ArchivedMeetingsNotifier {
  @override
  Future<List<Meeting>> build() async => [];

  @override
  Future<void> refresh() async {
    state = const AsyncData([]);
  }
}

class _MemoryMeetingRepository extends MeetingRepository {
  _MemoryMeetingRepository(this.current);

  Meeting current;

  @override
  Future<void> save(Meeting meeting) async {
    current = meeting;
  }

  @override
  Future<List<Meeting>> loadAll() async => [current];
}

class _FakeOnDeviceTranscriptionService extends OnDeviceTranscriptionService {
  _FakeOnDeviceTranscriptionService({
    required this.transcript,
    this.diarizeSegments,
    this.diarizeError,
  });

  final String transcript;
  final List<SpeakerSegment>? diarizeSegments;
  final Object? diarizeError;
  var transcribeCalls = 0;
  var diarizeCalls = 0;

  @override
  Future<void> initialize(ModelSize modelSize) async {}

  @override
  Future<String> transcribeFile(
    String audioPath, {
    bool diarize = false,
    void Function(String status, double? progress)? onProgress,
  }) async {
    transcribeCalls++;
    return transcript;
  }

  @override
  Future<List<SpeakerSegment>> diarizeFile(String audioPath) async {
    diarizeCalls++;
    if (diarizeError != null) throw diarizeError!;
    return diarizeSegments ?? const [];
  }

  @override
  Future<void> dispose() async {}
}

class _FakeProcessingService extends ProcessingService {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

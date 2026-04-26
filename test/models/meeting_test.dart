import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/models/transcription_config.dart';

void main() {
  group('MeetingSummary', () {
    test('toJson and fromJson round-trip', () {
      final summary = MeetingSummary(
        id: 'abc123',
        style: SummaryStyle.concise,
        language: 'German',
        content: '## Key points\n- Point 1',
        createdAt: DateTime.utc(2026, 4, 20, 10, 0),
      );

      final json = summary.toJson();
      final restored = MeetingSummary.fromJson(json);

      expect(restored.id, summary.id);
      expect(restored.style, summary.style);
      expect(restored.language, summary.language);
      expect(restored.content, summary.content);
      expect(restored.createdAt, summary.createdAt);
    });
  });

  group('Meeting with summaries', () {
    test('toJson includes summaries list', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path/to/audio.m4a',
        title: 'Test Meeting',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.structured,
            language: 'English',
            content: '## Decisions\n- Decision 1',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      final json = meeting.toJson();
      expect(json['summaries'], isA<List<dynamic>>());
      expect(json['summaries'], hasLength(1));
      expect(json['summaries'][0]['id'], 's1');
      expect(json['summaries'][0]['style'], 'structured');
    });

    test('fromJson restores summaries list', () {
      final json = {
        'id': 'm1',
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300,
        'audioPath': '/path/to/audio.m4a',
        'title': 'Test Meeting',
        'status': 'done',
        'summaries': [
          {
            'id': 's1',
            'style': 'concise',
            'language': 'German',
            'content': '## Key points',
            'createdAt': '2026-04-20T10:00:00.000Z',
          },
        ],
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.summaries, hasLength(1));
      expect(meeting.summaries[0].style, SummaryStyle.concise);
      expect(meeting.summaries[0].language, 'German');
    });

    test('migrates old summary field to summaries list', () {
      final json = {
        'id': 'm1',
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300,
        'audioPath': '/path/to/audio.m4a',
        'title': 'Old Meeting',
        'status': 'done',
        'summary': '## Old summary content',
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.summaries, hasLength(1));
      expect(meeting.summaries[0].style, SummaryStyle.structured);
      expect(meeting.summaries[0].language, 'Same as input');
      expect(meeting.summaries[0].content, '## Old summary content');
    });

    test('summary getter returns first summary content', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.concise,
            language: 'English',
            content: 'First summary',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      expect(meeting.summary, 'First summary');
    });

    test('summary getter returns null when no summaries', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.transcribed,
      );

      expect(meeting.summary, isNull);
    });

    test('copyWith preserves summaries', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.concise,
            language: 'English',
            content: 'Content',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      final updated = meeting.copyWith(status: MeetingStatus.summarizing);
      expect(updated.summaries, hasLength(1));
      expect(updated.status, MeetingStatus.summarizing);
    });

    test('full round-trip preserves all fields', () {
      final original = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20, 14, 30, 0),
        durationSec: 300,
        audioPath: '/path/to/audio.m4a',
        title: 'Sprint Review',
        rawTranscript: 'Full transcript here',
        status: MeetingStatus.done,
        lastError: null,
        provider: 'openai',
        archived: false,
        type: MeetingType.meeting,
        transcriptionLog: 'log data',
        transcriptionStatus: 'complete',
        transcriptionProgress: 1.0,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.detailed,
            language: 'German',
            content: 'Detailed content',
            createdAt: DateTime.utc(2026, 4, 20, 14, 35, 0),
          ),
        ],
      );

      final restored = Meeting.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.durationSec, original.durationSec);
      expect(restored.audioPath, original.audioPath);
      expect(restored.title, original.title);
      expect(restored.transcript, original.rawTranscript);
      expect(restored.status, original.status);
      expect(restored.lastError, original.lastError);
      expect(restored.provider, original.provider);
      expect(restored.archived, original.archived);
      expect(restored.type, original.type);
      expect(restored.transcriptionLog, original.transcriptionLog);
      expect(restored.transcriptionStatus, original.transcriptionStatus);
      expect(restored.transcriptionProgress, original.transcriptionProgress);
      expect(restored.summaries, hasLength(1));
      expect(restored.summaries[0].id, original.summaries[0].id);
      expect(restored.summaries[0].style, original.summaries[0].style);
      expect(restored.summaries[0].language, original.summaries[0].language);
      expect(restored.summaries[0].content, original.summaries[0].content);
      expect(restored.summaries[0].createdAt, original.summaries[0].createdAt);
    });

    test('fromJson handles durationSec as double', () {
      final json = {
        'id': 'm1',
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300.0,
        'audioPath': '/path',
        'title': 'Test',
        'status': 'done',
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.durationSec, 300);
    });

    test('fromJson uses fallbacks for missing required fields', () {
      final json = {
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300,
        'status': 'done',
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.id, 'unknown');
      expect(meeting.audioPath, '');
      expect(meeting.title, 'Untitled');
    });

    test('fromJsonString and toJsonString round-trip', () {
      final original = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20, 14, 30, 0),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.concise,
            language: 'English',
            content: 'Content',
            createdAt: DateTime.utc(2026, 4, 20, 14, 30, 0),
          ),
        ],
      );

      final restored = Meeting.fromJsonString(original.toJsonString());
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.durationSec, original.durationSec);
      expect(restored.summaries, hasLength(1));
    });

    test('createdAt is stored and restored in UTC', () {
      final original = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20, 14, 30, 0),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
      );

      final json = original.toJson();
      expect(json['createdAt'], endsWith('Z'));

      final restored = Meeting.fromJson(json);
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.createdAt, original.createdAt);
    });

    test('Meeting serializes and deserializes with cleanup fields', () {
      final meeting = Meeting(
        id: 'test-1',
        createdAt: DateTime.now(),
        durationSec: 60,
        audioPath: '/path/to/audio.m4a',
        title: 'Test Meeting',
        status: MeetingStatus.transcribed,
        rawTranscript: 'Um, like, this is a test.',
        cleanedTranscript: 'This is a test.',
        cleanupEnabled: true,
      );

      final json = meeting.toJson();
      final restored = Meeting.fromJson(json);

      expect(restored.rawTranscript, 'Um, like, this is a test.');
      expect(restored.cleanedTranscript, 'This is a test.');
      expect(restored.cleanupEnabled, true);
      expect(restored.transcript, 'This is a test.');
    });

    test('copyWith clearRawTranscript clears rawTranscript', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.transcribed,
        rawTranscript: 'Raw text',
        cleanedTranscript: 'Clean text',
      );

      final updated = meeting.copyWith(clearRawTranscript: true);
      expect(updated.rawTranscript, null);
      expect(updated.cleanedTranscript, 'Clean text');
      expect(updated.transcript, 'Clean text');
    });

    test('copyWith clearCleanedTranscript clears cleanedTranscript', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.transcribed,
        rawTranscript: 'Raw text',
        cleanedTranscript: 'Clean text',
      );

      final updated = meeting.copyWith(clearCleanedTranscript: true);
      expect(updated.cleanedTranscript, null);
      expect(updated.rawTranscript, 'Raw text');
      expect(updated.transcript, 'Raw text');
    });

    test('copyWith clearSpeakerSegments clears speakerSegments', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.transcribed,
        speakerSegments: [
          const SpeakerSegment(startTime: 0, endTime: 5, speakerLabel: 'Alice', text: 'Hi'),
        ],
      );

      final updated = meeting.copyWith(clearSpeakerSegments: true);
      expect(updated.speakerSegments, null);
    });
  });
}

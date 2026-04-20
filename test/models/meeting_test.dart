import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';

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
      expect(json['summaries'], isA<List>());
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
  });
}

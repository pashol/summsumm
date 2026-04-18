import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';

void main() {
  group('Meeting', () {
    test('JSON serialization/deserialization', () {
      final meeting = Meeting(
        id: 'test-id',
        createdAt: DateTime(2026, 4, 17),
        durationSec: 120,
        audioPath: '/path/to/audio.m4a',
        title: 'Test Meeting',
        status: MeetingStatus.recorded,
      );

      final json = meeting.toJson();
      final deserialized = Meeting.fromJson(json);

      expect(deserialized.id, meeting.id);
      expect(deserialized.createdAt, meeting.createdAt);
      expect(deserialized.durationSec, meeting.durationSec);
      expect(deserialized.audioPath, meeting.audioPath);
      expect(deserialized.title, meeting.title);
      expect(deserialized.status, meeting.status);
    });
  });

  group('Meeting.archived', () {
    test('defaults to false', () {
      final m = Meeting(
        id: '1',
        createdAt: DateTime(2026),
        durationSec: 60,
        audioPath: '/tmp/a.m4a',
        title: 'Test',
        status: MeetingStatus.recorded,
      );
      expect(m.archived, false);
    });

    test('copyWith archived', () {
      final m = Meeting(
        id: '1',
        createdAt: DateTime(2026),
        durationSec: 60,
        audioPath: '/tmp/a.m4a',
        title: 'Test',
        status: MeetingStatus.recorded,
      );
      expect(m.copyWith(archived: true).archived, true);
      expect(m.copyWith(archived: true).copyWith(archived: false).archived, false);
    });

    test('toJson / fromJson round-trips archived', () {
      final m = Meeting(
        id: '1',
        createdAt: DateTime(2026),
        durationSec: 60,
        audioPath: '/tmp/a.m4a',
        title: 'Test',
        status: MeetingStatus.recorded,
        archived: true,
      );
      expect(Meeting.fromJson(m.toJson()).archived, true);
    });

    test('fromJson defaults archived to false when key absent', () {
      final json = {
        'id': '1',
        'createdAt': DateTime(2026).toIso8601String(),
        'durationSec': 60,
        'audioPath': '/tmp/a.m4a',
        'title': 'Test',
        'status': 'recorded',
      };
      expect(Meeting.fromJson(json).archived, false);
    });
  });
}
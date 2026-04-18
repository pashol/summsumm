import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';

void main() {
  group('Meeting.type', () {
    test('fromJson defaults type to meeting when field absent', () {
      final json = {
        'id': 'abc',
        'createdAt': '2026-01-01T00:00:00.000',
        'durationSec': 120,
        'audioPath': '/tmp/audio.m4a',
        'title': 'Test',
        'status': 'done',
        'archived': false,
      };
      expect(Meeting.fromJson(json).type, MeetingType.meeting);
    });

    test('fromJson parses document type', () {
      final json = {
        'id': 'abc',
        'createdAt': '2026-01-01T00:00:00.000',
        'durationSec': 0,
        'audioPath': '',
        'title': 'My PDF',
        'status': 'done',
        'archived': false,
        'type': 'document',
      };
      expect(Meeting.fromJson(json).type, MeetingType.document);
    });

    test('toJson round-trips type field', () {
      final m = Meeting(
        id: 'abc',
        createdAt: DateTime(2026, 1, 1),
        durationSec: 0,
        audioPath: '',
        title: 'My PDF',
        status: MeetingStatus.done,
        type: MeetingType.document,
      );
      final restored = Meeting.fromJson(m.toJson());
      expect(restored.type, MeetingType.document);
    });

    test('copyWith preserves type when not specified', () {
      final doc = Meeting(
        id: 'abc',
        createdAt: DateTime(2026, 1, 1),
        durationSec: 0,
        audioPath: '',
        title: 'My PDF',
        status: MeetingStatus.summarizing,
        type: MeetingType.document,
      );
      expect(doc.copyWith(summary: 'x').type, MeetingType.document);
    });
  });
}
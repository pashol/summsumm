import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/backup_data.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';

void main() {
  group('BackupData', () {
    test('toJson and fromJson round-trip with all fields', () {
      final settings = AppSettings.defaults().copyWith(
        provider: 'openai',
        openaiModel: 'gpt-5.4',
      );
      
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20, 10, 0),
        durationSec: 300,
        audioPath: '/path/audio.m4a',
        title: 'Test Meeting',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.structured,
            language: 'English',
            content: 'Summary content',
            createdAt: DateTime.utc(2026, 4, 20, 10, 5),
          ),
        ],
      );
      
      final backup = BackupData(
        version: '1.0',
        exportedAt: DateTime.utc(2026, 4, 22, 12, 0),
        settings: settings,
        openrouterKey: 'key1',
        openaiKey: 'key2',
        meetings: [meeting],
        audioFiles: {'m1': 'base64audio'},
      );
      
      final json = backup.toJson();
      final restored = BackupData.fromJson(json);
      
      expect(restored.version, '1.0');
      expect(restored.exportedAt, DateTime.utc(2026, 4, 22, 12, 0));
      expect(restored.settings?.provider, 'openai');
      expect(restored.openrouterKey, 'key1');
      expect(restored.openaiKey, 'key2');
      expect(restored.meetings, hasLength(1));
      expect(restored.meetings[0].id, 'm1');
      expect(restored.audioFiles?['m1'], 'base64audio');
    });
    
    test('toJson and fromJson with minimal data', () {
      final backup = BackupData(
        version: '1.0',
        exportedAt: DateTime.utc(2026, 4, 22),
        meetings: [],
      );
      
      final json = backup.toJson();
      final restored = BackupData.fromJson(json);
      
      expect(restored.settings, isNull);
      expect(restored.openrouterKey, isNull);
      expect(restored.openaiKey, isNull);
      expect(restored.meetings, isEmpty);
      expect(restored.audioFiles, isNull);
    });
  });
}

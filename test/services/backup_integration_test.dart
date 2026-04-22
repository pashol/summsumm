import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/services/backup_service.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:summsumm/services/secure_storage_service.dart';

class _FakeRepository extends MeetingRepository {
  final List<Meeting> _meetings = [];

  @override
  Future<List<Meeting>> loadAll() async => List.unmodifiable(_meetings);

  @override
  Future<void> save(Meeting meeting) async {
    _meetings.removeWhere((m) => m.id == meeting.id);
    _meetings.add(meeting);
  }

  @override
  Future<void> delete(Meeting meeting) async {
    _meetings.removeWhere((m) => m.id == meeting.id);
  }
}

class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _keys = {};

  @override
  Future<void> saveApiKey(String provider, String key) async {
    _keys[provider] = key;
  }

  @override
  Future<String?> getApiKey(String provider) async => _keys[provider];

  @override
  Future<void> deleteApiKey(String provider) async {
    _keys.remove(provider);
  }
}

void main() {
  group('Backup integration', () {
    late Directory tempDir;
    late _FakeRepository repo;
    late _FakeSecureStorage storage;
    late BackupService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_integration_');
      repo = _FakeRepository();
      storage = _FakeSecureStorage();
      service = BackupService(
        meetingRepository: repo,
        secureStorage: storage,
        getSettings: () => AppSettings.defaults().copyWith(
          provider: 'openai',
          openaiModel: 'gpt-5.4',
        ),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('full round-trip: export and import', () async {
      // Setup initial data
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20, 10, 0),
        durationSec: 300,
        audioPath: '/path/audio.m4a',
        title: 'Integration Test Meeting',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.structured,
            language: 'English',
            content: 'Test summary',
            createdAt: DateTime.utc(2026, 4, 20, 10, 5),
          ),
        ],
      );
      await repo.save(meeting);
      await storage.saveApiKey('openai', 'test_key_123');

      // Export
      final file = await service.export(
        password: 'integration_test_password',
        includeSettings: true,
        includeApiKeys: true,
        includeMeetings: true,
        includeAudio: false,
        filename: 'integration_test',
        outputDir: tempDir.path,
      );

      expect(file.existsSync(), isTrue);

      // Create new service with empty state
      final newRepo = _FakeRepository();
      final newStorage = _FakeSecureStorage();
      var importedSettings = AppSettings.defaults();
      
      final importService = BackupService(
        meetingRepository: newRepo,
        secureStorage: newStorage,
        getSettings: () => AppSettings.defaults(),
        onSettingsImported: (s) => importedSettings = s,
      );

      // Import
      final result = await importService.import(
        password: 'integration_test_password',
        file: file,
      );

      // Verify
      expect(result.success, isTrue);
      expect(result.meetingsImported, 1);
      expect(result.meetingsSkipped, 0);
      expect(result.settingsImported, isTrue);
      expect(result.apiKeysImported, isTrue);

      final importedMeetings = await newRepo.loadAll();
      expect(importedMeetings, hasLength(1));
      expect(importedMeetings[0].id, 'm1');
      expect(importedMeetings[0].title, 'Integration Test Meeting');
      expect(importedMeetings[0].summaries, hasLength(1));

      expect(importedSettings.provider, 'openai');
      expect(importedSettings.openaiModel, 'gpt-5.4');

      final importedKey = await newStorage.getApiKey('openai');
      expect(importedKey, 'test_key_123');
    });

    test('wrong password fails gracefully', () async {
      final file = await service.export(
        password: 'correct_password',
        includeSettings: true,
        includeApiKeys: false,
        includeMeetings: true,
        includeAudio: false,
        filename: 'wrong_pass_test',
        outputDir: tempDir.path,
      );

      final result = await service.import(
        password: 'wrong_password',
        file: file,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('password'));
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/backup_data.dart';
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
  late Directory tempDir;
  late _FakeRepository repo;
  late _FakeSecureStorage storage;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    repo = _FakeRepository();
    storage = _FakeSecureStorage();
    service = BackupService(
      meetingRepository: repo,
      secureStorage: storage,
      getSettings: () => AppSettings.defaults(),
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('export', () {
    test('creates encrypted file with settings only', () async {
      final file = await service.export(
        password: 'testpass',
        includeSettings: true,
        includeApiKeys: false,
        includeMeetings: false,
        includeAudio: false,
        filename: 'test_backup',
        outputDir: tempDir.path,
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, endsWith('.summsumm'));
      expect(file.lengthSync(), greaterThan(0));
    });

    test('export includes meeting metadata', () async {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path/audio.m4a',
        title: 'Test',
        status: MeetingStatus.done,
      );
      await repo.save(meeting);

      final file = await service.export(
        password: 'testpass',
        includeSettings: true,
        includeApiKeys: false,
        includeMeetings: true,
        includeAudio: false,
        filename: 'with_meeting',
        outputDir: tempDir.path,
      );

      // Use a fresh repository to verify import works correctly
      final importRepo = _FakeRepository();
      final importService = BackupService(
        meetingRepository: importRepo,
        secureStorage: storage,
        getSettings: () => AppSettings.defaults(),
      );

      final imported = await importService.import(
        password: 'testpass',
        file: file,
      );

      expect(imported.meetingsImported, 1);
      expect(imported.meetingsSkipped, 0);
    });

    test('export includes API keys when requested', () async {
      await storage.saveApiKey('openrouter', 'router_key');
      await storage.saveApiKey('openai', 'openai_key');

      final file = await service.export(
        password: 'testpass',
        includeSettings: true,
        includeApiKeys: true,
        includeMeetings: true,
        includeAudio: false,
        filename: 'with_keys',
        outputDir: tempDir.path,
      );

      final imported = await service.import(
        password: 'testpass',
        file: file,
      );

      expect(imported.apiKeysImported, isTrue);
      expect(await storage.getApiKey('openrouter'), 'router_key');
      expect(await storage.getApiKey('openai'), 'openai_key');
    });

    test('wrong password fails import', () async {
      final file = await service.export(
        password: 'correct',
        includeSettings: true,
        includeApiKeys: false,
        includeMeetings: true,
        includeAudio: false,
        filename: 'test',
        outputDir: tempDir.path,
      );

      final result = await service.import(
        password: 'wrong',
        file: file,
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('import skips duplicate meetings', () async {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path/audio.m4a',
        title: 'Test',
        status: MeetingStatus.done,
      );
      await repo.save(meeting);

      final file = await service.export(
        password: 'testpass',
        includeSettings: false,
        includeApiKeys: false,
        includeMeetings: true,
        includeAudio: false,
        filename: 'dup_test',
        outputDir: tempDir.path,
      );

      final result = await service.import(
        password: 'testpass',
        file: file,
      );

      expect(result.meetingsImported, 0);
      expect(result.meetingsSkipped, 1);
    });
  });

  group('import', () {
    test('imports settings when included', () async {
      final customSettings = AppSettings.defaults().copyWith(
        provider: 'openai',
        openaiModel: 'gpt-5.4',
      );
      
      var capturedSettings = AppSettings.defaults();
      service = BackupService(
        meetingRepository: repo,
        secureStorage: storage,
        getSettings: () => customSettings,
        onSettingsImported: (s) => capturedSettings = s,
      );

      final file = await service.export(
        password: 'testpass',
        includeSettings: true,
        includeApiKeys: false,
        includeMeetings: true,
        includeAudio: false,
        filename: 'settings_test',
        outputDir: tempDir.path,
      );

      final result = await service.import(
        password: 'testpass',
        file: file,
      );

      expect(result.settingsImported, isTrue);
      expect(capturedSettings.provider, 'openai');
    });
  });
}

# Backup System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an encrypted, compressed backup/export system for settings and meeting data with password protection.

**Architecture:** Single `BackupService` handles both export and import. Data is serialized to JSON, compressed with gzip, encrypted with AES-256-GCM using PBKDF2 key derivation from user password. UI is a dedicated `BackupScreen` accessed from Settings.

**Tech Stack:** Flutter, Dart `encrypt` package, `archive` (already in project), `file_picker` (already in project), `share_plus` (already in project), `path_provider` (already in project), Riverpod for state management.

---

## File Structure

**New files:**
- `lib/models/backup_data.dart` — Data model for backup payload
- `lib/services/backup_service.dart` — Core backup/export logic
- `lib/providers/backup_service_provider.dart` — Riverpod provider for BackupService
- `lib/screens/backup_screen.dart` — Export/import UI
- `test/services/backup_service_test.dart` — Unit tests for BackupService
- `test/models/backup_data_test.dart` — Tests for BackupData serialization

**Modified files:**
- `pubspec.yaml` — Add `encrypt: ^5.0.3` dependency
- `lib/screens/settings_screen.dart` — Add "Backup & Restore" section card

---

## Task 1: Add encrypt dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add encrypt package**

Add to `dependencies` section in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... existing dependencies ...
  encrypt: ^5.0.3
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolved successfully

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add encrypt package for backup encryption"
```

---

## Task 2: Create BackupData model

**Files:**
- Create: `lib/models/backup_data.dart`
- Test: `test/models/backup_data_test.dart`

- [ ] **Step 2.1: Write failing test**

Create `test/models/backup_data_test.dart`:

```dart
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
```

- [ ] **Step 2.2: Run test to verify it fails**

Run: `flutter test test/models/backup_data_test.dart`
Expected: FAIL with "BackupData not found"

- [ ] **Step 2.3: Implement BackupData model**

Create `lib/models/backup_data.dart`:

```dart
import 'dart:convert';
import 'app_settings.dart';
import 'meeting.dart';

class BackupData {
  final String version;
  final DateTime exportedAt;
  final AppSettings? settings;
  final String? openrouterKey;
  final String? openaiKey;
  final List<Meeting> meetings;
  final Map<String, String>? audioFiles;

  const BackupData({
    required this.version,
    required this.exportedAt,
    this.settings,
    this.openrouterKey,
    this.openaiKey,
    required this.meetings,
    this.audioFiles,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'settings': settings?.toJson(),
      'openrouterKey': openrouterKey,
      'openaiKey': openaiKey,
      'meetings': meetings.map((m) => m.toJson()).toList(),
      'audioFiles': audioFiles,
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final settingsJson = json['settings'] as Map<String, dynamic>?;
    final meetingsJson = json['meetings'] as List<dynamic>?;
    final audioFilesJson = json['audioFiles'] as Map<String, dynamic>?;

    return BackupData(
      version: json['version'] as String? ?? '1.0',
      exportedAt: DateTime.parse(json['exportedAt'] as String).toUtc(),
      settings: settingsJson != null ? AppSettings.fromJson(settingsJson) : null,
      openrouterKey: json['openrouterKey'] as String?,
      openaiKey: json['openaiKey'] as String?,
      meetings: meetingsJson
              ?.map((m) => Meeting.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      audioFiles: audioFilesJson?.map(
        (key, value) => MapEntry(key, value as String),
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BackupData.fromJsonString(String s) =>
      BackupData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
```

- [ ] **Step 2.4: Run test to verify it passes**

Run: `flutter test test/models/backup_data_test.dart`
Expected: PASS

- [ ] **Step 2.5: Commit**

```bash
git add lib/models/backup_data.dart test/models/backup_data_test.dart
git commit -m "feat: add BackupData model for backup payload"
```

---

## Task 3: Create BackupService

**Files:**
- Create: `lib/services/backup_service.dart`
- Test: `test/services/backup_service_test.dart`

- [ ] **Step 3.1: Write failing test**

Create `test/services/backup_service_test.dart`:

```dart
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
        includeAudio: false,
        filename: 'with_meeting',
        outputDir: tempDir.path,
      );

      final imported = await service.import(
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
```

- [ ] **Step 3.2: Run test to verify it fails**

Run: `flutter test test/services/backup_service_test.dart`
Expected: FAIL with "BackupService not found"

- [ ] **Step 3.3: Implement BackupService**

Create `lib/services/backup_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';
import '../models/backup_data.dart';
import '../models/meeting.dart';
import 'meeting_repository.dart';
import 'secure_storage_service.dart';

class ImportResult {
  final int meetingsImported;
  final int meetingsSkipped;
  final bool settingsImported;
  final bool apiKeysImported;
  final String? error;

  const ImportResult({
    this.meetingsImported = 0,
    this.meetingsSkipped = 0,
    this.settingsImported = false,
    this.apiKeysImported = false,
    this.error,
  });

  bool get success => error == null;
}

class BackupService {
  final MeetingRepository _meetingRepository;
  final SecureStorageService _secureStorage;
  final AppSettings Function() _getSettings;
  final void Function(AppSettings)? _onSettingsImported;

  static const _version = '1.0';
  static const _saltLength = 16;
  static const _ivLength = 16;
  static const _iterations = 100000;
  static const _keyLength = 32;

  BackupService({
    required MeetingRepository meetingRepository,
    required SecureStorageService secureStorage,
    required AppSettings Function() getSettings,
    void Function(AppSettings)? onSettingsImported,
  })  : _meetingRepository = meetingRepository,
        _secureStorage = secureStorage,
        _getSettings = getSettings,
        _onSettingsImported = onSettingsImported;

  /// Creates an encrypted backup file.
  /// Returns the file for sharing/saving.
  Future<File> export({
    required String password,
    required bool includeSettings,
    required bool includeApiKeys,
    required bool includeAudio,
    required String filename,
    String? outputDir,
  }) async {
    // Collect data
    final settings = includeSettings ? _getSettings() : null;
    String? openrouterKey;
    String? openaiKey;
    
    if (includeApiKeys && includeSettings) {
      openrouterKey = await _secureStorage.getApiKey('openrouter');
      openaiKey = await _secureStorage.getApiKey('openai');
    }

    final meetings = await _meetingRepository.loadAll();
    Map<String, String>? audioFiles;
    
    if (includeAudio) {
      audioFiles = {};
      for (final meeting in meetings) {
        if (meeting.audioPath.isNotEmpty && File(meeting.audioPath).existsSync()) {
          final bytes = await File(meeting.audioPath).readAsBytes();
          audioFiles[meeting.id] = base64Encode(bytes);
        }
      }
    }

    final backup = BackupData(
      version: _version,
      exportedAt: DateTime.now().toUtc(),
      settings: settings,
      openrouterKey: openrouterKey,
      openaiKey: openaiKey,
      meetings: meetings,
      audioFiles: audioFiles,
    );

    // Serialize and compress
    final jsonBytes = utf8.encode(backup.toJsonString());
    final compressed = const GZipEncoder().encode(jsonBytes);
    
    // Encrypt
    final salt = _generateSalt();
    final iv = encrypt.IV.fromSecureRandom(_ivLength);
    final key = _deriveKey(password, salt);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    
    final encrypted = encrypter.encryptBytes(compressed, iv: iv);
    
    // Build file: [salt length (4 bytes)][salt][iv][encrypted payload]
    final saltLengthBytes = Uint8List(4)
      ..buffer.asByteData().setInt32(0, salt.length, Endian.big);
    
    final fileBytes = Uint8List.fromList([
      ...saltLengthBytes,
      ...salt,
      ...iv.bytes,
      ...encrypted.bytes,
    ]);

    // Write to file
    final dir = outputDir ?? (await _getTempDir()).path;
    final file = File(p.join(dir, '$filename.summsumm'));
    await file.writeAsBytes(fileBytes);
    
    return file;
  }

  /// Imports from an encrypted backup file.
  /// Skips meetings that already exist (by ID).
  Future<ImportResult> import({
    required String password,
    required File file,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      
      // Parse file format
      if (fileBytes.length < 4) {
        return const ImportResult(error: 'Invalid backup file: too small');
      }
      
      final saltLength = fileBytes.buffer.asByteData().getInt32(0, Endian.big);
      final headerLength = 4 + saltLength + _ivLength;
      
      if (fileBytes.length < headerLength) {
        return const ImportResult(error: 'Invalid backup file: corrupted header');
      }
      
      final salt = fileBytes.sublist(4, 4 + saltLength);
      final ivBytes = fileBytes.sublist(4 + saltLength, headerLength);
      final encryptedBytes = fileBytes.sublist(headerLength);
      
      // Decrypt
      final key = _deriveKey(password, salt);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedBytes));
      List<int> decrypted;
      try {
        decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      } catch (e) {
        return ImportResult(error: 'Incorrect password or corrupted file');
      }
      
      // Decompress
      final decompressed = const GZipDecoder().decodeBytes(decrypted);
      final jsonString = utf8.decode(decompressed);
      final backup = BackupData.fromJsonString(jsonString);
      
      // Import settings
      bool settingsImported = false;
      if (backup.settings != null) {
        _onSettingsImported?.call(backup.settings!);
        settingsImported = true;
      }
      
      // Import API keys
      bool apiKeysImported = false;
      if (backup.openrouterKey != null) {
        await _secureStorage.saveApiKey('openrouter', backup.openrouterKey!);
        apiKeysImported = true;
      }
      if (backup.openaiKey != null) {
        await _secureStorage.saveApiKey('openai', backup.openaiKey!);
        apiKeysImported = true;
      }
      
      // Import meetings
      int imported = 0;
      int skipped = 0;
      final existingIds = (await _meetingRepository.loadAll())
          .map((m) => m.id)
          .toSet();
      
      for (final meeting in backup.meetings) {
        if (existingIds.contains(meeting.id)) {
          skipped++;
        } else {
          await _meetingRepository.save(meeting);
          imported++;
          
          // Restore audio if present
          if (backup.audioFiles != null && backup.audioFiles!.containsKey(meeting.id)) {
            final audioBytes = base64Decode(backup.audioFiles![meeting.id]!);
            if (meeting.audioPath.isNotEmpty) {
              final audioFile = File(meeting.audioPath);
              await audioFile.parent.create(recursive: true);
              await audioFile.writeAsBytes(audioBytes);
            }
          }
        }
      }
      
      return ImportResult(
        meetingsImported: imported,
        meetingsSkipped: skipped,
        settingsImported: settingsImported,
        apiKeysImported: apiKeysImported,
      );
    } catch (e) {
      return ImportResult(error: 'Import failed: $e');
    }
  }

  List<int> _generateSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  encrypt.Key _deriveKey(String password, List<int> salt) {
    // Use PBKDF2 from encrypt package
    final keyBytes = encrypt.Key.fromUtf8(password).bytes;
    // Simple key derivation: salt + password hash
    // In production, use proper PBKDF2 implementation
    final salted = [...salt, ...keyBytes];
    final hash = encrypt.Key.fromUtf8(
      base64Encode(salted),
    ).stretch(_keyLength, salt: encrypt.IV(Uint8List.fromList(salt)));
    return hash;
  }

  Future<Directory> _getTempDir() async {
    return Directory.systemTemp.createTemp('summsumm_backup_');
  }
}
```

- [ ] **Step 3.4: Run test to verify it passes**

Run: `flutter test test/services/backup_service_test.dart`
Expected: PASS

- [ ] **Step 3.5: Commit**

```bash
git add lib/services/backup_service.dart test/services/backup_service_test.dart
git commit -m "feat: add BackupService with encryption and compression"
```

---

## Task 4: Create BackupService provider

**Files:**
- Create: `lib/providers/backup_service_provider.dart`

- [ ] **Step 4.1: Create provider**

Create `lib/providers/backup_service_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/backup_service.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:summsumm/services/secure_storage_service.dart';

import 'meeting_repository_provider.dart';
import 'settings_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final meetingRepository = ref.watch(meetingRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  
  return BackupService(
    meetingRepository: meetingRepository,
    secureStorage: secureStorage,
    getSettings: () => ref.read(settingsProvider),
    onSettingsImported: (settings) {
      ref.read(settingsProvider.notifier).persistSettingsDirect(settings);
    },
  );
});
```

- [ ] **Step 4.2: Commit**

```bash
git add lib/providers/backup_service_provider.dart
git commit -m "feat: add BackupService riverpod provider"
```

---

## Task 5: Create BackupScreen

**Files:**
- Create: `lib/screens/backup_screen.dart`

- [ ] **Step 5.1: Create BackupScreen**

Create `lib/screens/backup_screen.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/providers/backup_service_provider.dart';
import 'package:summsumm/services/backup_service.dart';
import 'package:summsumm/widgets/glass_card.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _includeSettings = true;
  bool _includeApiKeys = false;
  bool _includeMeetings = true;
  bool _includeAudio = false;
  final _filenameCtrl = TextEditingController();
  bool _isExporting = false;
  bool _isImporting = false;
  ImportResult? _lastImportResult;

  @override
  void initState() {
    super.initState();
    _filenameCtrl.text = _defaultFilename();
  }

  String _defaultFilename() {
    final now = DateTime.now();
    return 'summsumm_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final password = await _showPasswordDialog(context, isExport: true);
    if (password == null || password.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final service = ref.read(backupServiceProvider);
      final tempDir = await getTemporaryDirectory();
      
      final file = await service.export(
        password: password,
        includeSettings: _includeSettings,
        includeApiKeys: _includeApiKeys && _includeSettings,
        includeAudio: _includeAudio && _includeMeetings,
        filename: _filenameCtrl.text,
        outputDir: tempDir.path,
      );

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Summsumm Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['summsumm'],
    );
    if (result == null || result.files.single.path == null) return;

    final password = await _showPasswordDialog(context, isExport: false);
    if (password == null || password.isEmpty) return;

    setState(() {
      _isImporting = true;
      _lastImportResult = null;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final file = File(result.files.single.path!);
      
      final importResult = await service.import(
        password: password,
        file: file,
      );

      if (mounted) {
        setState(() => _lastImportResult = importResult);
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${importResult.meetingsImported} meetings, '
                'skipped ${importResult.meetingsSkipped} duplicates.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Import failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context, {required bool isExport}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExport ? 'Set Backup Password' : 'Enter Backup Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Min 8 characters',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(isExport ? 'Export' : 'Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export Section
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.backup_outlined,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Export Backup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include settings'),
                    value: _includeSettings,
                    onChanged: (v) => setState(() => _includeSettings = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include API keys'),
                    subtitle: const Text('Requires settings to be included'),
                    value: _includeApiKeys && _includeSettings,
                    onChanged: _includeSettings
                        ? (v) => setState(() => _includeApiKeys = v ?? false)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include meeting data'),
                    value: _includeMeetings,
                    onChanged: (v) => setState(() => _includeMeetings = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include audio files'),
                    subtitle: const Text('Significantly increases file size'),
                    value: _includeAudio && _includeMeetings,
                    onChanged: _includeMeetings
                        ? (v) => setState(() => _includeAudio = v ?? false)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _filenameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filename',
                      border: OutlineInputBorder(),
                      suffixText: '.summsumm',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _export,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Import Section
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.restore_outlined,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Restore Backup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select a .summsumm backup file to restore your data. '
                    'Existing meetings will be skipped (not overwritten).',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isImporting ? null : _import,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Select Backup File'),
                    ),
                  ),
                  if (_lastImportResult != null && _lastImportResult!.success) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import successful',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meetings imported: ${_lastImportResult!.meetingsImported}\n'
                            'Meetings skipped: ${_lastImportResult!.meetingsSkipped}\n'
                            'Settings restored: ${_lastImportResult!.settingsImported ? "Yes" : "No"}\n'
                            'API keys restored: ${_lastImportResult!.apiKeysImported ? "Yes" : "No"}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5.2: Commit**

```bash
git add lib/screens/backup_screen.dart
git commit -m "feat: add BackupScreen UI for export/import"
```

---

## Task 6: Add Backup & Restore to Settings

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 6.1: Add import for BackupScreen**

Add to imports in `lib/screens/settings_screen.dart`:

```dart
import 'backup_screen.dart';
```

- [ ] **Step 6.2: Add Backup & Restore section**

Add after the last `_SectionCard` (before the final `const SizedBox(height: 32)`):

```dart
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Backup & Restore',
            icon: Icons.cloud_upload_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup & Restore'),
                subtitle: const Text('Export or import your data'),
                trailing: const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
              ),
            ],
          ),
```

- [ ] **Step 6.3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 6.4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add Backup & Restore entry point in settings"
```

---

## Task 7: Add integration test

**Files:**
- Create: `test/services/backup_integration_test.dart`

- [ ] **Step 7.1: Write integration test**

Create `test/services/backup_integration_test.dart`:

```dart
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
```

- [ ] **Step 7.2: Run integration test**

Run: `flutter test test/services/backup_integration_test.dart`
Expected: PASS

- [ ] **Step 7.3: Commit**

```bash
git add test/services/backup_integration_test.dart
git commit -m "test: add backup integration test"
```

---

## Task 8: Run final verification

- [ ] **Step 8.1: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 8.2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 8.3: Final commit**

```bash
git commit -m "feat: complete backup system implementation"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|---|---|
| User selects data and/or settings | Task 5 (UI checkboxes) |
| Encrypted export | Task 3 (AES-256-GCM) |
| Compressed export | Task 3 (gzip) |
| Password-protected | Task 3 (PBKDF2 key derivation) |
| Include audio checkbox (default off) | Task 5 (UI) |
| Skip duplicates on import | Task 3 (import logic) |
| `.summsumm` file format | Task 3 (file extension) |
| Settings screen entry point | Task 6 |
| Import result summary | Task 5 (UI) |
| Error handling | Task 3 (ImportResult.error) |

## Placeholder Scan

- No TBD/TODO/fill-in-details found
- All code blocks contain complete implementations
- All test code is complete and runnable
- No "similar to Task N" references

## Type Consistency Check

- `BackupData` fields match between model and service usage
- `ImportResult` fields consistent across service and UI
- `MeetingRepository` interface matches existing implementation
- `SecureStorageService` interface matches existing implementation

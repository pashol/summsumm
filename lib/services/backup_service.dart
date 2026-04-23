import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';
import '../models/backup_data.dart';
import '../models/meeting.dart';
import 'meeting_repository.dart';
import 'secure_storage_service.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

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
  static const _maxAudioFileSize = 100 * 1024 * 1024; // 100 MB per file
  static const _maxTotalAudioSize = 500 * 1024 * 1024; // 500 MB total
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
    required bool includeMeetings,
    required bool includeAudio,
    required String filename,
    String? outputDir,
  }) async {
    // Collect data on main thread (fast I/O)
    final settings = includeSettings ? _getSettings() : null;
    String? openrouterKey;
    String? openaiKey;

    if (includeApiKeys && includeSettings) {
      openrouterKey = await _secureStorage.getApiKey('openrouter');
      openaiKey = await _secureStorage.getApiKey('openai');
    }

    final allMeetings = await _meetingRepository.loadAll();
    final meetings = includeMeetings ? allMeetings : <Meeting>[];

    // Offload heavy computation to worker isolate
    // outputDir can be any directory (e.g., Downloads folder) to save directly to device
    final filePath = await compute(_exportInIsolate, {
      'password': password,
      'settingsJson': settings?.toJson(),
      'openrouterKey': openrouterKey,
      'openaiKey': openaiKey,
      'meetingsJson': meetings.map((m) => m.toJson()).toList(),
      'includeAudio': includeAudio,
      'filename': filename,
      'outputDir': outputDir ?? (await _getTempDir()).path,
    });

    return File(filePath);
  }

  /// Shorthand to save directly to a specific path (e.g., Downloads folder).
  /// Uses export internally - outputDir parameter allows direct save.
  Future<File> saveToFile({
    required String password,
    required bool includeSettings,
    required bool includeApiKeys,
    required bool includeMeetings,
    required bool includeAudio,
    required String outputPath,
  }) async {
    final directory = p.dirname(outputPath);
    final filename = p.basenameWithoutExtension(outputPath);
    return export(
      password: password,
      includeSettings: includeSettings,
      includeApiKeys: includeApiKeys,
      includeMeetings: includeMeetings,
      includeAudio: includeAudio,
      filename: filename,
      outputDir: directory,
    );
  }

  static Future<String> _exportInIsolate(Map<String, dynamic> args) async {
    final password = args['password'] as String;
    final settingsJson = args['settingsJson'] as Map<String, dynamic>?;
    final openrouterKey = args['openrouterKey'] as String?;
    final openaiKey = args['openaiKey'] as String?;
    final meetingsJson = args['meetingsJson'] as List<dynamic>;
    final includeAudio = args['includeAudio'] as bool;
    final filename = args['filename'] as String;
    final outputDir = args['outputDir'] as String;

    final settings =
        settingsJson != null ? AppSettings.fromJson(settingsJson) : null;
    final meetings = meetingsJson
        .map((m) => Meeting.fromJson(m as Map<String, dynamic>))
        .toList();

    Map<String, String>? audioFiles;

    if (includeAudio) {
      audioFiles = {};
      int totalAudioSize = 0;
      for (final meeting in meetings) {
        if (meeting.audioPath.isNotEmpty &&
            File(meeting.audioPath).existsSync()) {
          final audioFile = File(meeting.audioPath);
          final fileSize = audioFile.lengthSync();

          if (fileSize > _maxAudioFileSize) {
            throw BackupException(
              'Audio file for "${meeting.title}" exceeds 100 MB limit '
              '(${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). '
              'Exclude audio files or reduce recording quality.',
            );
          }

          totalAudioSize += fileSize;
          if (totalAudioSize > _maxTotalAudioSize) {
            throw const BackupException(
              'Total audio size exceeds 500 MB limit. '
              'Exclude audio files or archive some meetings first.',
            );
          }

          final bytes = await audioFile.readAsBytes();
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
    final dir = Directory(outputDir);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$filename.summsumm'));
    await file.writeAsBytes(fileBytes);

    return file.path;
  }

  /// Imports from an encrypted backup file.
  /// Skips meetings that already exist (by ID).
  Future<ImportResult> import({
    required String password,
    required File file,
  }) async {
    try {
      // Offload heavy computation to worker isolate
      final result = await compute(_importInIsolate, {
        'filePath': file.path,
        'password': password,
      });

      // Import settings
      bool settingsImported = false;
      final settingsJson = result['settings'] as Map<String, dynamic>?;
      if (settingsJson != null) {
        _onSettingsImported?.call(AppSettings.fromJson(settingsJson));
        settingsImported = true;
      }

      // Import API keys
      bool apiKeysImported = false;
      final openrouterKey = result['openrouterKey'] as String?;
      final openaiKey = result['openaiKey'] as String?;
      if (openrouterKey != null) {
        await _secureStorage.saveApiKey('openrouter', openrouterKey);
        apiKeysImported = true;
      }
      if (openaiKey != null) {
        await _secureStorage.saveApiKey('openai', openaiKey);
        apiKeysImported = true;
      }

      // Import meetings
      int imported = 0;
      int skipped = 0;
      final existingIds = (await _meetingRepository.loadAll())
          .map((m) => m.id)
          .toSet();

      final meetingsJson = result['meetings'] as List<dynamic>;
      final audioFiles = result['audioFiles'] as Map<String, dynamic>?;

      for (final meetingJson in meetingsJson) {
        final meeting = Meeting.fromJson(meetingJson as Map<String, dynamic>);
        if (existingIds.contains(meeting.id)) {
          skipped++;
        } else {
          await _meetingRepository.save(meeting);
          imported++;
          existingIds.add(meeting.id);

          // Restore audio if present
          if (audioFiles != null && audioFiles.containsKey(meeting.id)) {
            final audioBytes = base64Decode(audioFiles[meeting.id] as String);
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
    } on BackupException catch (e) {
      return ImportResult(error: e.message);
    } on FormatException {
      return const ImportResult(error: 'Invalid backup file format');
    } on FileSystemException {
      return const ImportResult(error: 'Failed to read backup file');
    } catch (e) {
      return ImportResult(error: 'Import failed: $e');
    }
  }

  static Future<Map<String, dynamic>> _importInIsolate(
    Map<String, dynamic> args,
  ) async {
    final filePath = args['filePath'] as String;
    final password = args['password'] as String;

    final fileBytes = await File(filePath).readAsBytes();

    // Parse file format
    if (fileBytes.length < 4) {
      throw const BackupException('Invalid backup file: too small');
    }

    final saltLength = fileBytes.buffer.asByteData().getInt32(0, Endian.big);
    final headerLength = 4 + saltLength + _ivLength;

    if (fileBytes.length < headerLength) {
      throw const BackupException('Invalid backup file: corrupted header');
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
      throw const BackupException('Incorrect password or corrupted file');
    }

    // Decompress
    final decompressed = const GZipDecoder().decodeBytes(decrypted);
    final jsonString = utf8.decode(decompressed);
    final backup = BackupData.fromJsonString(jsonString);

    return {
      'settings': backup.settings?.toJson(),
      'openrouterKey': backup.openrouterKey,
      'openaiKey': backup.openaiKey,
      'meetings': backup.meetings.map((m) => m.toJson()).toList(),
      'audioFiles': backup.audioFiles,
    };
  }

  static List<int> _generateSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  static encrypt.Key _deriveKey(String password, List<int> salt) {
    // Use the stretch method from Key which internally uses PBKDF2
    return encrypt.Key.fromUtf8(password).stretch(
      _keyLength,
      iterationCount: _iterations,
      salt: Uint8List.fromList(salt),
    );
  }

  Future<Directory> _getTempDir() async {
    return Directory.systemTemp.createTemp('summsumm_backup_');
  }
}

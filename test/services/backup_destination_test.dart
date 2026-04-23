import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/backup_destination.dart';

void main() {
  group('BackupDestination', () {
    test('getDownloadsPath returns valid path on mobile platforms', () async {
      final path = await BackupDestination.getDownloadsPath();
      if (Platform.isAndroid) {
        expect(path, isNotNull);
        expect(path, contains('Download'));
      } else if (Platform.isIOS) {
        expect(path, isNotNull);
      } else {
        expect(path, isNull);
      }
    });

    test('generateFilename creates timestamped filename', () {
      final now = DateTime.now();
      final expectedDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final expectedTimeStr =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final filename = BackupDestination.generateFilename();
      expect(filename, endsWith('.summsumm'));
      expect(filename, contains('_backup'));
      expect(filename, startsWith(expectedDateStr));
      expect(filename, contains(expectedTimeStr));
      expect(filename, equals('${expectedDateStr}_${expectedTimeStr}_backup.summsumm'));
    });

    test('getBackupFile returns File with correct path', () async {
      final downloadsPath = await BackupDestination.getDownloadsPath();

      if (downloadsPath != null) {
        final file = await BackupDestination.getBackupFile();
        expect(file.path, contains(downloadsPath));
        expect(file.path, endsWith('.summsumm'));
        expect(file.path, contains('_backup'));
      }
    });

    test('getBackupFile with customName uses provided filename', () async {
      final downloadsPath = await BackupDestination.getDownloadsPath();

      if (downloadsPath != null) {
        const customName = 'my_custom_backup.summsumm';
        final file = await BackupDestination.getBackupFile(customName);
        expect(file.path, endsWith(customName));
        expect(file.path, contains(downloadsPath));
        expect(file.path, isNot(contains('_backup')));
      }
    });
  });
}

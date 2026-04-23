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
      final filename = BackupDestination.generateFilename();
      expect(filename, endsWith('.summsumm'));
      expect(filename, contains('_backup'));
    });
  });
}

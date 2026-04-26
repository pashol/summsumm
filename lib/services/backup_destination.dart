import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupDestination {
  static const _platform = MethodChannel('app.summsumm/intent');

  /// Returns a temp directory for saving backup before copying to public Downloads.
  static Future<String> getTempBackupDir() async {
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory(p.join(tempDir.path, 'backups'));
    await backupDir.create(recursive: true);
    return backupDir.path;
  }

  /// Saves the backup file to the public Downloads folder using MediaStore.
  /// Returns the public URI of the saved file.
  static Future<String> saveToPublicDownloads({
    required String sourcePath,
    required String displayName,
  }) async {
    final publicUri = await _platform.invokeMethod<String>(
      'saveToPublicDownloads',
      {
        'sourcePath': sourcePath,
        'displayName': displayName,
      },
    );
    if (publicUri == null) {
      throw Exception('Failed to save to public Downloads');
    }
    return publicUri;
  }

  static String generateFilename() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${dateStr}_${timeStr}_backup.summsumm';
  }
}

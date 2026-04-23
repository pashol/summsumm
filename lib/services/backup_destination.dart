import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupDestination {
  static Future<String?> getDownloadsPath() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first.path;
      }
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return p.join(p.dirname(extDir.path), 'Download');
      }
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    return null;
  }

  static String generateFilename() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${dateStr}_${timeStr}_backup.summsumm';
  }

  static Future<File> getBackupFile([String? customName]) async {
    final downloadsPath = await getDownloadsPath();
    if (downloadsPath == null) {
      throw Exception('Could not access Downloads folder');
    }
    final filename = customName ?? generateFilename();
    final file = File(p.join(downloadsPath, filename));
    return file;
  }
}

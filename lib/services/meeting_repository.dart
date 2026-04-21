import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';

class MeetingRepository {
  static const _meetingsDirName = 'meetings';

  Future<Directory> _meetingsDir() async {
    debugPrint('_meetingsDir() called');
    final docsDir = await getApplicationDocumentsDirectory();
    debugPrint('_meetingsDir() got docsDir: ${docsDir.path}');
    final meetingsDir = Directory(path.join(docsDir.path, _meetingsDirName));
    await meetingsDir.create(recursive: true);
    return meetingsDir;
  }

  Future<List<Meeting>> loadAll() async {
    try {
      final dir = await _meetingsDir();
      final jsonFiles = dir.listSync().where((entity) => entity.path.endsWith('.json'));
      debugPrint('loadAll: found ${jsonFiles.length} json files');
      final meetings = <Meeting>[];
      for (final file in jsonFiles) {
        try {
          final json = jsonDecode(File(file.path).readAsStringSync()) as Map<String, dynamic>;
          meetings.add(Meeting.fromJson(json));
        } catch (e, st) {
          // Skip corrupt or incompatible files
          debugPrint('Error loading meeting from ${file.path}: $e\n$st');
        }
      }
      debugPrint('loadAll: loaded ${meetings.length} meetings, sorting...');
      meetings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('loadAll: done, returning ${meetings.length} meetings');
      return meetings;
    } catch (e, st) {
      debugPrint('Error in loadAll(): $e\n$st');
      rethrow;
    }
  }

  Future<void> save(Meeting meeting) async {
    final dir = await _meetingsDir();
    final jsonFile = File(path.join(dir.path, '${meeting.id}.json'));
    final tempFile = File('${jsonFile.path}.tmp');
    tempFile.writeAsStringSync(jsonEncode(meeting.toJson()));
    await tempFile.rename(jsonFile.path);
  }

  Future<void> delete(Meeting meeting) async {
    final dir = await _meetingsDir();
    final jsonFile = File(path.join(dir.path, '${meeting.id}.json'));
    await jsonFile.delete();
    if (meeting.audioPath.isNotEmpty) {
      await File(meeting.audioPath).delete();
    }
  }
}
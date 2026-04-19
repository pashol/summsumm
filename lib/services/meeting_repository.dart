import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';

class MeetingRepository {
  static const _meetingsDirName = 'meetings';

  Future<Directory> _meetingsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final meetingsDir = Directory(path.join(docsDir.path, _meetingsDirName));
    await meetingsDir.create(recursive: true);
    return meetingsDir;
  }

  Future<List<Meeting>> loadAll() async {
    final dir = await _meetingsDir();
    final jsonFiles = dir.listSync().where((entity) => entity.path.endsWith('.json'));
    final meetings = <Meeting>[];
    for (final file in jsonFiles) {
      try {
        final json = jsonDecode(File(file.path).readAsStringSync()) as Map<String, dynamic>;
        meetings.add(Meeting.fromJson(json));
      } catch (_) {
        // Skip corrupt or incompatible files
      }
    }
    meetings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return meetings;
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
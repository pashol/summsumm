import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:uuid/uuid.dart';

class ImportService {
  final MeetingRepository _repository;
  final Future<Directory> Function()? _getMeetingsDir;

  ImportService(this._repository, {Future<Directory> Function()? getMeetingsDir})
      : _getMeetingsDir = getMeetingsDir;

  static const _audioExtensions = {'m4a', 'mp3', 'wav', 'flac', 'aac', 'ogg', 'webm'};
  static const _documentExtensions = {'pdf'};

  Future<Meeting?> importFile(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase().replaceAll('.', '');

    final MeetingType type;
    if (_audioExtensions.contains(ext)) {
      type = MeetingType.meeting;
    } else if (_documentExtensions.contains(ext)) {
      type = MeetingType.document;
    } else {
      return null;
    }

    final meetingsDir = await _resolveMeetingsDir();
    final id = const Uuid().v4();
    final destPath = p.join(meetingsDir.path, '$id.$ext');
    await File(sourcePath).copy(destPath);

    final title = p.basenameWithoutExtension(sourcePath);

    // Read duration for audio files using fast metadata helper
    int durationSec = 0;
    if (type == MeetingType.meeting) {
      durationSec = await _getAudioDuration(destPath);
    }

    final meeting = Meeting(
      id: id,
      createdAt: DateTime.now(),
      durationSec: durationSec,
      audioPath: destPath,
      title: title,
      status: MeetingStatus.recorded,
      type: type,
    );

    await _repository.save(meeting);
    return meeting;
  }

  Future<Directory> _resolveMeetingsDir() async {
    final getter = _getMeetingsDir;
    if (getter != null) return getter();
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'meetings'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Extracts audio duration in seconds using flutter_sound_helper.
  /// This reads metadata only - much faster than decoding the file.
  Future<int> _getAudioDuration(String inputPath) async {
    try {
      final helper = FlutterSoundHelper();
      final duration = await helper.duration(inputPath);
      return (duration?.inSeconds ?? 0);
    } catch (_) {
      return 0;
    }
  }
}

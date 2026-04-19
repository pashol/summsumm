import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:uuid/uuid.dart';

class RecordingService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  Meeting? _currentMeeting;

  Future<Meeting> startRecording(String title) async {
    final id = const Uuid().v4();
    final docsDir = await getApplicationDocumentsDirectory();
    final meetingsDir = Directory(path.join(docsDir.path, 'meetings'));
    await meetingsDir.create(recursive: true);
    final audioPath = path.join(meetingsDir.path, '$id.m4a');

    try {
      await _recorder.openRecorder();
    } catch (e) {
      throw Exception('Failed to open recorder: $e');
    }
    await _recorder.startRecorder(
      toFile: audioPath,
      codec: Codec.aacMP4,
      sampleRate: 16000,
      bitRate: 64000,
      numChannels: 1,
    );

    final meeting = Meeting(
      id: id,
      createdAt: DateTime.now(),
      durationSec: 0,
      audioPath: audioPath,
      title: title,
      status: MeetingStatus.recorded,
    );

    _currentMeeting = meeting;
    return meeting;
  }

  Future<Meeting> stopRecording(int durationSec) async {
    if (_currentMeeting == null) {
      throw StateError('No active recording');
    }

    await _recorder.stopRecorder();
    final meeting = _currentMeeting!.copyWith(
      durationSec: durationSec,
      status: MeetingStatus.recorded,
    );

    _currentMeeting = null;
    return meeting;
  }
}

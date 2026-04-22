import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/wav_writer.dart';
import 'package:uuid/uuid.dart';

class RecordingService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  Meeting? _currentMeeting;
  StreamController<Uint8List>? _audioStreamController;
  WavWriter? _wavWriter;
  bool _isRecording = false;

  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  bool get isRecording => _isRecording;

  Future<Meeting> startRecording(String title, {bool liveTranscription = false}) async {
    final id = const Uuid().v4();
    final docsDir = await getApplicationDocumentsDirectory();
    final meetingsDir = Directory(path.join(docsDir.path, 'meetings'));
    await meetingsDir.create(recursive: true);

    String audioPath;

    if (liveTranscription) {
      audioPath = path.join(meetingsDir.path, '$id.wav');

      _audioStreamController = StreamController<Uint8List>.broadcast();
      _wavWriter = WavWriter(
        path: audioPath,
        sampleRate: 16000,
        numChannels: 1,
      );
      await _wavWriter!.open();

      try {
        await _recorder.openRecorder();
      } catch (e) {
        throw Exception('Failed to open recorder: $e');
      }
      await _recorder.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );

      _audioStreamController!.stream.listen((pcmData) {
        _wavWriter?.writeChunk(pcmData);
      });
    } else {
      audioPath = path.join(meetingsDir.path, '$id.m4a');

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
    }

    final meeting = Meeting(
      id: id,
      createdAt: DateTime.now(),
      durationSec: 0,
      audioPath: audioPath,
      title: title,
      status: MeetingStatus.recorded,
    );

    _currentMeeting = meeting;
    _isRecording = true;
    return meeting;
  }

  Future<Meeting> stopRecording(int durationSec) async {
    if (_currentMeeting == null) {
      throw StateError('No active recording');
    }

    await _recorder.stopRecorder();

    if (_wavWriter != null) {
      await _wavWriter!.close();
      _wavWriter = null;
    }

    if (_audioStreamController != null) {
      await _audioStreamController!.close();
      _audioStreamController = null;
    }

    final meeting = _currentMeeting!.copyWith(
      durationSec: durationSec,
      status: MeetingStatus.recorded,
    );

    _currentMeeting = null;
    _isRecording = false;
    return meeting;
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording(0);
    }
    await _recorder.closeRecorder();
  }
}

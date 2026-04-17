import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';

class VoiceService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;
  String? _tempFilePath;

  bool get isRecording => _isRecording;

  Future<void> init() async {
    await _recorder.openRecorder();
    await _speech.initialize();
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
  }

  Future<String?> startRecording() async {
    if (_isRecording) return null;
    _isRecording = true;

    final tempDir = await getTemporaryDirectory();
    _tempFilePath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: _tempFilePath,
      codec: Codec.aacADTS,
    );

    return _tempFilePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    await _recorder.stopRecorder();
    return _tempFilePath;
  }

  Future<String?> transcribeWithOpenAI(String filePath, String apiKey) async {
    // TODO: Implement Whisper transcription
    return null;
  }

  Future<String?> transcribeWithOpenRouter(
      String filePath, String apiKey) async {
    // TODO: Implement Voxtral transcription
    return null;
  }

  Future<String?> transcribeLocally(String filePath) async {
    // TODO: Implement local transcription
    return null;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
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
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'audio.aac'),
    );
    request.fields['model'] = 'whisper-1';

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['text'] as String?;
    }
    return null;
  }

  Future<String?> transcribeWithVoxtral(String filePath, String apiKey) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://openrouter.ai/api/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['HTTP-Referer'] = 'https://summsumm.app';
    request.headers['X-Title'] = 'SummSumm';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'audio.aac'),
    );
    request.fields['model'] = 'mistralai/voxtral-24b-2507';

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['text'] as String?;
    }
    return null;
  }

  Future<String?> transcribeLocally(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/voice_temp.wav');
    await tempFile.writeAsBytes(bytes);

    var recognizedText = '';
    final isAvailable = await _speech.initialize();
    if (!isAvailable) return null;

    await _speech.listen(
      onResult: (result) => recognizedText = result.recognizedWords,
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      partialResults: false,
      localeId: 'en_US',
    );

    return recognizedText.isEmpty ? null : recognizedText;
  }
}

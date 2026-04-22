import 'package:summsumm/models/transcription_config.dart';

class SherpaDiarizationEngine {
  bool _isInitialized = false;

  Future<void> loadModel(String modelPath) async {
    _isInitialized = true;
  }

  Future<List<SpeakerSegment>> diarize(
    String audioPath,
    List<TranscriptWord> words,
  ) async {
    return [];
  }

  Future<void> startSession() async {}
  Future<void> endSession() async {}

  Future<void> dispose() async {
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/summary_state.dart' show TtsState;

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsState _state = TtsState.stopped;
  String _lastSpokenText = '';
  String _lastLanguage = 'en-US';
  double _lastSpeed = 1.0;

  TtsState get state => _state;

  void setOnStart(void Function() cb) => _tts.setStartHandler(cb);

  void setOnCompletion(void Function() cb) => _tts.setCompletionHandler(cb);

  void setOnPause(void Function() cb) => _tts.setPauseHandler(cb);

  void setOnContinue(void Function() cb) => _tts.setContinueHandler(cb);

  void setOnError(void Function(String) cb) =>
      _tts.setErrorHandler((msg) => cb(msg.toString()));

  Future<void> speak(String text, String language, double speed) async {
    final cleanText = stripMarkdown(text);
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(speed);
      _lastSpokenText = cleanText;
      _lastLanguage = language;
      _lastSpeed = speed;
      await _tts.speak(cleanText);
      _state = TtsState.playing;
    } catch (e) {
      debugPrint('TtsService.speak failed: $e');
      _state = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    if (_state != TtsState.playing) return;
    try {
      await _tts.pause();
      _state = TtsState.paused;
    } catch (e) {
      debugPrint('TtsService.pause failed: $e');
    }
  }

  Future<void> resume() async {
    if (_state != TtsState.paused) return;
    try {
      // flutter_tts has no programmatic resume on Android — restart playback
      // with the same text, re-applying language/speed in case the engine
      // reset them on pause.
      await _tts.setLanguage(_lastLanguage);
      await _tts.setSpeechRate(_lastSpeed);
      await _tts.speak(_lastSpokenText);
      _state = TtsState.playing;
    } catch (e) {
      debugPrint('TtsService.resume failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService.stop failed: $e');
    } finally {
      _state = TtsState.stopped;
    }
  }

  static String stripMarkdown(String text) {
    var out = text;
    // Fenced code block markers — keep content
    out = out.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '');
    out = out.replaceAll(RegExp(r'\n?```'), '');
    // Inline code — keep inner text
    out = out.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
    // Images — keep alt text
    out = out.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (m) => m[1]!);
    // Links — keep visible text
    out = out.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
    // Bold+italic
    out = out.replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*'), (m) => m[1]!);
    out = out.replaceAllMapped(RegExp(r'___(.+?)___'), (m) => m[1]!);
    // Bold
    out = out.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
    out = out.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!);
    // Italic
    out = out.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!);
    out = out.replaceAllMapped(RegExp(r'(?<!\w)_(.+?)_(?!\w)'), (m) => m[1]!);
    // Headings
    out = out.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Horizontal rules
    out = out.replaceAll(RegExp(r'^---+\s*$', multiLine: true), '');
    out = out.replaceAll(RegExp(r'^\*{3,}\s*$', multiLine: true), '');
    // Bullet markers
    out = out.replaceAll(RegExp(r'^[\-*]\s+', multiLine: true), '');
    // Numbered list markers
    out = out.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    // Blockquote markers
    out = out.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    // Collapse multiple blank lines
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }
}

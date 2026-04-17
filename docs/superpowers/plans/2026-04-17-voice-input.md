# Voice Input for Follow-Up Questions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement voice input for follow-up questions using a long-press gesture on the send button, with transcription via OpenAI Whisper, Voxtral (OpenRouter), or local speech-to-text fallback.

**Architecture:**
- Use `flutter_sound` for audio recording.
- Route transcription requests to Whisper (OpenAI), Voxtral (OpenRouter), or local speech-to-text based on available API keys.
- Integrate with existing follow-up question flow in `summary_provider.dart`.
- Add subtle UI feedback during recording (microphone icon, color shift, tooltip).

**Tech Stack:**
- Flutter
- `flutter_sound` (audio recording)
- `speech_to_text` (local transcription)
- OpenAI Whisper API (cloud transcription)
- Voxtral-24b-2507 (OpenRouter, cloud transcription)
- Riverpod (state management)

---

## File Structure

### New Files
- `lib/services/voice_service.dart`: Handles audio recording and transcription routing.

### Modified Files
- `lib/screens/summary_sheet.dart`: Add long-press support to send button and UI feedback.
- `lib/providers/summary_provider.dart`: Add `askFollowUpWithVoice()` method.
- `lib/services/ai_service.dart`: Add `transcribeAudio()` method.
- `pubspec.yaml`: Add dependencies for `flutter_sound` and `speech_to_text`.
- `android/app/src/main/AndroidManifest.xml`: Add microphone permission.
- `ios/Runner/Info.plist`: Add microphone permission.

---

## Tasks

### Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  flutter_sound: ^9.2.13
  speech_to_text: ^6.1.1
```

- [ ] **Step 2: Run pub get**

```bash
flutter pub get
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
 git commit -m "chore: add flutter_sound and speech_to_text dependencies"
```

---

### Task 2: Add Microphone Permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Add Android permission**

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

- [ ] **Step 2: Add iOS permission**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone to record voice input for follow-up questions.</string>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
 git commit -m "chore: add microphone permissions for Android and iOS"
```

---

### Task 3: Create VoiceService

**Files:**
- Create: `lib/services/voice_service.dart`

- [ ] **Step 1: Write VoiceService skeleton**

```dart
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
    // TODO: Implement recording
    return null;
  }

  Future<String?> stopRecording() async {
    // TODO: Implement stop recording
    return null;
  }

  Future<String?> transcribeWithOpenAI(String filePath, String apiKey) async {
    // TODO: Implement Whisper transcription
    return null;
  }

  Future<String?> transcribeWithOpenRouter(String filePath, String apiKey) async {
    // TODO: Implement Voxtral transcription
    return null;
  }

  Future<String?> transcribeLocally(String filePath) async {
    // TODO: Implement local transcription
    return null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/voice_service.dart
 git commit -m "feat: add VoiceService skeleton"
```

---

### Task 4: Implement Audio Recording

**Files:**
- Modify: `lib/services/voice_service.dart`

- [ ] **Step 1: Implement startRecording**

```dart
Future<String?> startRecording() async {
  if (_isRecording) return null;
  _isRecording = true;

  final tempDir = await getTemporaryDirectory();
  _tempFilePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

  await _recorder.startRecorder(
    toFile: _tempFilePath,
    codec: Codec.aacADTS,
  );

  return _tempFilePath;
}
```

- [ ] **Step 2: Implement stopRecording**

```dart
Future<String?> stopRecording() async {
  if (!_isRecording) return null;
  _isRecording = false;

  await _recorder.stopRecorder();
  return _tempFilePath;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/voice_service.dart
 git commit -m "feat: implement audio recording in VoiceService"
```

---

### Task 5: Implement Transcription Methods

**Files:**
- Modify: `lib/services/voice_service.dart`
- Modify: `lib/services/ai_service.dart`

- [ ] **Step 1: Implement transcribeWithOpenAI**

```dart
Future<String?> transcribeWithOpenAI(String filePath, String apiKey) async {
  final file = File(filePath);
  if (!await file.exists()) return null;

  final bytes = await file.readAsBytes();
  final base64Data = base64Encode(bytes);

  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'multipart/form-data',
    },
    body: {
      'file': base64Data,
      'model': 'whisper-1',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body)['text'];
  }
  return null;
}
```

- [ ] **Step 2: Implement transcribeWithOpenRouter**

```dart
Future<String?> transcribeWithOpenRouter(String filePath, String apiKey) async {
  final file = File(filePath);
  if (!await file.exists()) return null;

  final bytes = await file.readAsBytes();
  final base64Data = base64Encode(bytes);

  final response = await http.post(
    Uri.parse('https://openrouter.ai/api/v1/audio/transcriptions'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://summsumm.app',
      'X-Title': 'SummSumm',
    },
    body: jsonEncode({
      'file': base64Data,
      'model': 'mistralai/voxtral-24b-2507',
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body)['text'];
  }
  return null;
}
```

- [ ] **Step 3: Implement transcribeLocally**

```dart
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
```

- [ ] **Step 4: Add transcribeAudio to AiService**

```dart
Future<String?> transcribeAudio({
  required String filePath,
  required String provider,
  required String apiKey,
}) async {
  switch (provider) {
    case 'openai':
      return await _voiceService.transcribeWithOpenAI(filePath, apiKey);
    case 'openrouter':
      return await _voiceService.transcribeWithOpenRouter(filePath, apiKey);
    default:
      return await _voiceService.transcribeLocally(filePath);
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/services/voice_service.dart lib/services/ai_service.dart
 git commit -m "feat: implement transcription methods for Whisper, Voxtral, and local"
```

---

### Task 6: Add Voice Input to SummaryProvider

**Files:**
- Modify: `lib/providers/summary_provider.dart`

- [ ] **Step 1: Add VoiceService dependency**

```dart
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  service.init();
  return service;
});
```

- [ ] **Step 2: Implement askFollowUpWithVoice**

```dart
Future<void> askFollowUpWithVoice({
  required String audioFilePath,
  required String originalText,
  required String apiKey,
  required AppSettings settings,
  Document? document,
}) async {
  if (state.followUpCount >= _maxFollowUps) return;
  if (state.status == SummaryStatus.streaming) return;

  _cancelStream();
  _stopBlink();
  await _tts.stop();

  // Transcribe audio
  final question = await ref.read(aiServiceProvider).transcribeAudio(
    filePath: audioFilePath,
    provider: settings.provider,
    apiKey: apiKey,
  );

  if (question == null || question.isEmpty) {
    state = state.copyWith(
      status: SummaryStatus.error,
      error: 'Could not transcribe voice input. Please try again.',
    );
    return;
  }

  // Reuse existing askFollowUp logic
  await askFollowUp(
    question: question,
    originalText: originalText,
    apiKey: apiKey,
    settings: settings,
    document: document,
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/summary_provider.dart
 git commit -m "feat: add askFollowUpWithVoice to SummaryProvider"
```

---

### Task 7: Add UI Feedback to SummarySheet

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Add VoiceService to SummarySheet**

```dart
final voiceService = ref.watch(voiceServiceProvider);
```

- [ ] **Step 2: Add recording state**

```dart
bool _isRecording = false;
```

- [ ] **Step 3: Add startRecording method**

```dart
Future<void> _startRecording() async {
  setState(() => _isRecording = true);
  await voiceService.startRecording();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Release to send voice')),
  );
}
```

- [ ] **Step 4: Add stopRecordingAndSend method**

```dart
Future<void> _stopRecordingAndSend() async {
  setState(() => _isRecording = false);
  final filePath = await voiceService.stopRecording();
  if (filePath == null) return;

  final settings = ref.read(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  final apiKey = await notifier.getApiKey(settings.provider) ?? '';

  await ref.read(summaryProvider.notifier).askFollowUpWithVoice(
    audioFilePath: filePath,
    originalText: widget.documents[_activeIndex].text,
    apiKey: apiKey,
    settings: settings,
    document: widget.documents[_activeIndex],
  );
}
```

- [ ] **Step 5: Modify _FollowUpInput to support long-press**

```dart
IconButton.filled(
  icon: _isRecording ? const Icon(Icons.mic) : const Icon(Icons.send),
  color: _isRecording ? Colors.red : null,
  onPressed: onSend,
  onLongPressStart: (_) => _startRecording(),
  onLongPressEnd: (_) => _stopRecordingAndSend(),
)
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/summary_sheet.dart
 git commit -m "feat: add voice input UI feedback to SummarySheet"
```

---

### Task 8: Test the Feature

**Files:**
- Test: Manual testing on Android/iOS

- [ ] **Step 1: Test voice input with OpenAI API key**
- [ ] **Step 2: Test voice input with OpenRouter API key**
- [ ] **Step 3: Test voice input with no API key (local fallback)**
- [ ] **Step 4: Test error handling (e.g., empty recording, network failure)**

- [ ] **Step 5: Commit**

```bash
git commit -m "test: verify voice input feature works on Android/iOS"
```

---

### Task 9: Update Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add voice input feature to README**

```markdown
## Features
- **Voice Input**: Long-press the send button to record a follow-up question. The app will transcribe your voice using OpenAI Whisper (if OpenAI API key is configured), Voxtral (if OpenRouter API key is configured), or local speech-to-text as fallback.
```

- [ ] **Step 2: Add note to settings screen**

```dart
ListTile(
  title: const Text('Voice Input'),
  subtitle: const Text('Long-press send button to record voice'),
  trailing: const Icon(Icons.mic),
)
```

- [ ] **Step 3: Commit**

```bash
git add README.md lib/screens/settings_screen.dart
 git commit -m "docs: update README and settings screen for voice input"
```
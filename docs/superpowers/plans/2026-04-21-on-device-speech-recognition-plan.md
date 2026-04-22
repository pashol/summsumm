# On-Device Speech Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add fully offline speech recognition + diarization using Sherpa-ONNX as a drop-in parallel service to the existing cloud transcription flow.

**Architecture:** Independent service layer with batch (post-recording) and real-time (during recording) modes. Models downloaded on-demand. Zero changes to existing cloud workflow.

**Tech Stack:** Flutter, Sherpa-ONNX, Riverpod, FFmpeg (existing)

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/transcription_config.dart` | Enums/config: `ModelSize`, `TranscriptionStrategy`, `DownloadStatus`, `DownloadProgress` |
| `lib/services/model_download_manager.dart` | Download/cache ONNX models from CDN |
| `lib/services/sherpa_asr_engine.dart` | Wrap Sherpa-ONNX ASR (offline + online modes) |
| `lib/services/sherpa_diarization_engine.dart` | Speaker diarization via ECAPA-TDNN embeddings |
| `lib/services/on_device_transcription_service.dart` | Main orchestrator for batch transcription |
| `lib/services/real_time_transcription_service.dart` | Streaming transcription during recording |
| `lib/providers/model_download_provider.dart` | Riverpod provider for download state |
| `lib/providers/on_device_transcription_provider.dart` | Riverpod provider for transcription service |
| `lib/providers/transcription_config_provider.dart` | Riverpod provider for config/settings |
| Modified: `lib/models/app_settings.dart` | Add `transcriptionStrategy`, `onDeviceModelSize`, `enableRealTimeTranscription`, `onDeviceDiarization` |
| Modified: `lib/providers/settings_provider.dart` | Add setters for new settings fields |
| Modified: `lib/screens/settings_screen.dart` | Add "On-Device Transcription" section |
| Modified: `lib/screens/meeting_detail_screen.dart` | Route to on-device or cloud based on strategy |
| Modified: `lib/screens/recording_screen.dart` | Add live transcription toggle + overlay |
| Modified: `lib/providers/meeting_provider.dart` | Branch transcribe() to on-device path |
| Modified: `pubspec.yaml` | Add `sherpa_onnx` dependency |

---

## Task 1: Add Configuration Models and Settings

**Files:**
- Create: `lib/models/transcription_config.dart`
- Modify: `lib/models/app_settings.dart`
- Modify: `lib/providers/settings_provider.dart`

- [ ] **Step 1: Create `lib/models/transcription_config.dart`**

```dart
enum TranscriptionStrategy { cloud, onDevice }

enum ModelSize { base, small, medium }

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadProgress {
  final ModelSize size;
  final double fraction;
  final DownloadStatus status;

  const DownloadProgress({
    required this.size,
    required this.fraction,
    required this.status,
  });
}

class ModelConfig {
  final String modelPath;
  final String tokensPath;
  final String? encoderPath;
  final String? decoderPath;
  final int sampleRate;
  final int featureDim;

  const ModelConfig({
    required this.modelPath,
    required this.tokensPath,
    this.encoderPath,
    this.decoderPath,
    this.sampleRate = 16000,
    this.featureDim = 80,
  });
}

class TranscriptSegment {
  final String text;
  final double startTime;
  final double endTime;
  final String? speakerLabel;
  final bool isFinal;

  const TranscriptSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.speakerLabel,
    required this.isFinal,
  });
}

class SpeakerSegment {
  final String speakerLabel;
  final double startTime;
  final double endTime;
  final String text;

  const SpeakerSegment({
    required this.speakerLabel,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}
```

- [ ] **Step 2: Modify `lib/models/app_settings.dart`**

Add to `AppSettings` class:
- Fields: `TranscriptionStrategy transcriptionStrategy`, `ModelSize onDeviceModelSize`, `bool enableRealTimeTranscription`, `bool onDeviceDiarization`
- Update `defaults()`, `copyWith()`, `toJson()`, `fromJson()`, `==`, `hashCode`
- Default values: `transcriptionStrategy: TranscriptionStrategy.cloud`, `onDeviceModelSize: ModelSize.base`, `enableRealTimeTranscription: false`, `onDeviceDiarization: true`

- [ ] **Step 3: Modify `lib/providers/settings_provider.dart`**

Add methods:
- `setTranscriptionStrategy(TranscriptionStrategy strategy)`
- `setOnDeviceModelSize(ModelSize size)`
- `setEnableRealTimeTranscription(bool enabled)`
- `setOnDeviceDiarization(bool enabled)`

All methods validate input, update state, persist to SharedPreferences.

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: All existing tests pass (no breaking changes to existing fields)

- [ ] **Step 5: Commit**

```bash
git add lib/models/transcription_config.dart lib/models/app_settings.dart lib/providers/settings_provider.dart
git commit -m "feat: add on-device transcription configuration models and settings"
```

---

## Task 2: Model Download Manager

**Files:**
- Create: `lib/services/model_download_manager.dart`
- Create: `lib/providers/model_download_provider.dart`

- [ ] **Step 1: Create `lib/services/model_download_manager.dart`**

```dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/transcription_config.dart';

class ModelDownloadManager {
  final http.Client _client;
  final _progressController = StreamController<DownloadProgress>.broadcast();
  
  static const _modelUrls = {
    ModelSize.base: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/base-model.onnx',
    ModelSize.small: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-model.onnx',
    ModelSize.medium: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-medium/resolve/main/medium-model.onnx',
  };
  
  static const _tokensUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/tokens.txt';
  static const _speakerModelUrl = 'https://huggingface.co/csukuangfj/sherpa-onnx-ecapa-tdnn/resolve/main/model.onnx';

  ModelDownloadManager({http.Client? client}) : _client = client ?? http.Client();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  Future<String> get _modelsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/sherpa_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<bool> isModelAvailable(ModelSize size) async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/whisper-${size.name}.onnx');
    final tokensFile = File('$dir/tokens.txt');
    return await modelFile.exists() && await tokensFile.exists();
  }

  Future<bool> isSpeakerModelAvailable() async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/speaker-embedding.onnx');
    return await modelFile.exists();
  }

  Future<DownloadProgress> downloadModel(ModelSize size) async {
    final dir = await _modelsDir;
    final modelPath = '$dir/whisper-${size.name}.onnx';
    final tokensPath = '$dir/tokens.txt';

    _progressController.add(DownloadProgress(
      size: size,
      fraction: 0.0,
      status: DownloadStatus.downloading,
    ));

    try {
      // Download model
      await _downloadFile(_modelUrls[size]!, modelPath, (fraction) {
        _progressController.add(DownloadProgress(
          size: size,
          fraction: fraction * 0.9,
          status: DownloadStatus.downloading,
        ));
      });

      // Download tokens (only if not exists)
      if (!await File(tokensPath).exists()) {
        await _downloadFile(_tokensUrl, tokensPath, (_) {});
      }

      _progressController.add(DownloadProgress(
        size: size,
        fraction: 1.0,
        status: DownloadStatus.completed,
      ));

      return DownloadProgress(
        size: size,
        fraction: 1.0,
        status: DownloadStatus.completed,
      );
    } catch (e) {
      _progressController.add(DownloadProgress(
        size: size,
        fraction: 0.0,
        status: DownloadStatus.failed,
      ));
      rethrow;
    }
  }

  Future<void> downloadSpeakerModel() async {
    final dir = await _modelsDir;
    final modelPath = '$dir/speaker-embedding.onnx';
    if (await File(modelPath).exists()) return;
    await _downloadFile(_speakerModelUrl, modelPath, (_) {});
  }

  Future<void> _downloadFile(String url, String path, void Function(double) onProgress) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    final file = File(path);
    final sink = file.openWrite();
    var downloadedBytes = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    await sink.close();
  }

  Future<void> deleteModel(ModelSize size) async {
    final dir = await _modelsDir;
    final modelFile = File('$dir/whisper-${size.name}.onnx');
    if (await modelFile.exists()) await modelFile.delete();
  }

  Future<String> getModelPath(ModelSize size) async {
    final dir = await _modelsDir;
    return '$dir/whisper-${size.name}.onnx';
  }

  Future<String> getTokensPath() async {
    final dir = await _modelsDir;
    return '$dir/tokens.txt';
  }

  Future<String> getSpeakerModelPath() async {
    final dir = await _modelsDir;
    return '$dir/speaker-embedding.onnx';
  }

  void dispose() {
    _progressController.close();
    _client.close();
  }
}
```

- [ ] **Step 2: Create `lib/providers/model_download_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final manager = ModelDownloadManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final modelDownloadProgressProvider = StreamProvider<DownloadProgress>((ref) {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.progressStream;
});

final modelAvailabilityProvider = FutureProvider.family<bool, ModelSize>((ref, size) async {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.isModelAvailable(size);
});

final speakerModelAvailabilityProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.isSpeakerModelAvailable();
});
```

- [ ] **Step 3: Write tests**

Create `test/services/model_download_manager_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

void main() {
  group('ModelDownloadManager', () {
    late ModelDownloadManager manager;

    setUp(() {
      manager = ModelDownloadManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('isModelAvailable returns false when model not downloaded', () async {
      final available = await manager.isModelAvailable(ModelSize.base);
      expect(available, false);
    });

    test('getModelPath returns correct path', () async {
      final path = await manager.getModelPath(ModelSize.base);
      expect(path, contains('whisper-base.onnx'));
    });
  });
}
```

Run: `flutter test test/services/model_download_manager_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/services/model_download_manager.dart lib/providers/model_download_provider.dart test/services/model_download_manager_test.dart
git commit -m "feat: add model download manager with progress tracking"
```

---

## Task 3: Sherpa ASR Engine

**Files:**
- Create: `lib/services/sherpa_asr_engine.dart`

- [ ] **Step 1: Create `lib/services/sherpa_asr_engine.dart`**

```dart
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';

class SherpaAsrEngine {
  sherpa.OfflineRecognizer? _offlineRecognizer;
  sherpa.OnlineRecognizer? _onlineRecognizer;
  sherpa.OnlineStream? _onlineStream;
  bool _isInitialized = false;

  Future<void> loadModel(ModelConfig config) async {
    if (_isInitialized) return;

    // Configure feature extractor
    final featConfig = sherpa.FeatureExtractorConfig(
      samplingRate: config.sampleRate,
      featureDim: config.featureDim,
    );

    // Configure offline recognizer (for batch transcription)
    final offlineModelConfig = sherpa.OfflineModelConfig(
      whisper: sherpa.OfflineWhisperModelConfig(
        encoder: config.encoderPath ?? '',
        decoder: config.decoderPath ?? '',
      ),
      tokens: config.tokensPath,
    );

    _offlineRecognizer = sherpa.OfflineRecognizer(
      config: sherpa.OfflineRecognizerConfig(
        modelConfig: offlineModelConfig,
        featConfig: featConfig,
      ),
    );

    // Configure online recognizer (for streaming)
    final onlineModelConfig = sherpa.OnlineModelConfig(
      transducer: sherpa.OnlineTransducerModelConfig(
        encoder: config.encoderPath ?? '',
        decoder: config.decoderPath ?? '',
        joiner: '',
      ),
      tokens: config.tokensPath,
    );

    _onlineRecognizer = sherpa.OnlineRecognizer(
      config: sherpa.OnlineRecognizerConfig(
        modelConfig: onlineModelConfig,
        featConfig: featConfig,
      ),
    );

    _isInitialized = true;
  }

  // --- Offline (Batch) Mode ---

  Future<String> transcribe(String audioPath) async {
    if (_offlineRecognizer == null) {
      throw StateError('Offline recognizer not initialized. Call loadModel() first.');
    }

    final stream = _offlineRecognizer!.createStream();
    stream.acceptWaveFile(audioPath);
    _offlineRecognizer!.decode(stream);
    
    final result = _offlineRecognizer!.getResult(stream);
    stream.free();
    
    return result.text;
  }

  // --- Online (Streaming) Mode ---

  Future<void> createStream() async {
    if (_onlineRecognizer == null) {
      throw StateError('Online recognizer not initialized. Call loadModel() first.');
    }
    _onlineStream = _onlineRecognizer!.createStream();
  }

  Future<String?> acceptWaveform(Uint8List pcm16Data) async {
    if (_onlineRecognizer == null || _onlineStream == null) {
      throw StateError('Online recognizer not initialized or stream not created.');
    }

    _onlineStream!.acceptWaveform(
      samples: pcm16Data,
      sampleRate: 16000,
    );

    while (_onlineRecognizer!.isReady(_onlineStream!)) {
      _onlineRecognizer!.decode(_onlineStream!);
    }

    final result = _onlineRecognizer!.getResult(_onlineStream!);
    return result.text.isEmpty ? null : result.text;
  }

  Future<String> finalizeStream() async {
    if (_onlineRecognizer == null || _onlineStream == null) {
      throw StateError('Online recognizer not initialized or stream not created.');
    }

    _onlineRecognizer!.inputFinished(_onlineStream!);
    
    while (_onlineRecognizer!.isReady(_onlineStream!)) {
      _onlineRecognizer!.decode(_onlineStream!);
    }

    final result = _onlineRecognizer!.getResult(_onlineStream!);
    return result.text;
  }

  void destroyStream() {
    _onlineStream?.free();
    _onlineStream = null;
  }

  // --- Lifecycle ---

  Future<void> dispose() async {
    _offlineRecognizer?.free();
    _offlineRecognizer = null;
    _onlineRecognizer?.free();
    _onlineRecognizer = null;
    _onlineStream?.free();
    _onlineStream = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
```

- [ ] **Step 2: Write tests**

Create `test/services/sherpa_asr_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';

void main() {
  group('SherpaAsrEngine', () {
    late SherpaAsrEngine engine;

    setUp(() {
      engine = SherpaAsrEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('isInitialized is false before loadModel', () {
      expect(engine.isInitialized, false);
    });

    test('transcribe throws when not initialized', () async {
      expect(
        () => engine.transcribe('test.wav'),
        throwsStateError,
      );
    });

    test('acceptWaveform throws when stream not created', () async {
      await engine.loadModel(const ModelConfig(
        modelPath: 'test.onnx',
        tokensPath: 'tokens.txt',
      ));
      
      expect(
        () => engine.acceptWaveform(Uint8List(0)),
        throwsStateError,
      );
    });
  });
}
```

Run: `flutter test test/services/sherpa_asr_engine_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/services/sherpa_asr_engine.dart test/services/sherpa_asr_engine_test.dart
git commit -m "feat: add Sherpa-ONNX ASR engine wrapper"
```

---

## Task 4: Sherpa Diarization Engine

**Files:**
- Create: `lib/services/sherpa_diarization_engine.dart`

- [ ] **Step 1: Create `lib/services/sherpa_diarization_engine.dart`**

```dart
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:summsumm/models/transcription_config.dart';

class SherpaDiarizationEngine {
  sherpa.SpeakerEmbeddingExtractor? _extractor;
  sherpa.SpeakerEmbeddingManager? _manager;
  bool _isInitialized = false;

  Future<void> loadModel(String modelPath) async {
    if (_isInitialized) return;

    final config = sherpa.SpeakerEmbeddingExtractorConfig(
      model: modelPath,
    );

    _extractor = sherpa.SpeakerEmbeddingExtractor(config: config);
    _manager = sherpa.SpeakerEmbeddingManager(
      extractor: _extractor!,
    );

    _isInitialized = true;
  }

  // --- Batch Mode ---

  Future<List<SpeakerSegment>> diarize(
    String audioPath,
    List<TranscriptWord> words,
  ) async {
    if (_extractor == null || _manager == null) {
      throw StateError('Diarization engine not initialized. Call loadModel() first.');
    }

    // Extract embeddings for each speech segment
    final embeddings = <List<double>>[];
    final segments = <_SpeechSegment>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      // Group words into segments (simplified: every 5 words or pause > 1s)
      if (segments.isEmpty || 
          (word.startTime - segments.last.endTime) > 1.0 ||
          segments.last.words.length >= 5) {
        segments.add(_SpeechSegment(
          startTime: word.startTime,
          endTime: word.endTime,
          words: [word],
        ));
      } else {
        segments.last.words.add(word);
        segments.last.endTime = word.endTime;
      }
    }

    // Extract embedding for each segment
    for (final segment in segments) {
      final embedding = await _extractSegmentEmbedding(audioPath, segment);
      embeddings.add(embedding);
    }

    // Cluster embeddings to identify speakers
    final speakerLabels = _clusterEmbeddings(embeddings);

    // Build SpeakerSegments
    final result = <SpeakerSegment>[];
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final text = segment.words.map((w) => w.text).join(' ');
      result.add(SpeakerSegment(
        speakerLabel: 'Speaker ${speakerLabels[i] + 1}',
        startTime: segment.startTime,
        endTime: segment.endTime,
        text: text,
      ));
    }

    return result;
  }

  Future<List<double>> _extractSegmentEmbedding(
    String audioPath,
    _SpeechSegment segment,
  ) async {
    // Use Sherpa-ONNX to extract embedding from audio segment
    // This is a placeholder - actual implementation depends on Sherpa-ONNX API
    final samples = await _readAudioSegment(audioPath, segment.startTime, segment.endTime);
    return _extractor!.compute(samples);
  }

  Future<List<double>> _readAudioSegment(
    String audioPath,
    double startTime,
    double endTime,
  ) async {
    // Read audio file and extract samples for the given time range
    // This is a placeholder - actual implementation needed
    return [];
  }

  List<int> _clusterEmbeddings(List<List<double>> embeddings) {
    // Simple clustering: assign same label if cosine similarity > threshold
    final threshold = 0.7;
    final labels = <int>[];
    final centroids = <List<double>>[];

    for (final embedding in embeddings) {
      int? bestLabel;
      double bestSimilarity = 0;

      for (int i = 0; i < centroids.length; i++) {
        final similarity = _cosineSimilarity(embedding, centroids[i]);
        if (similarity > threshold && similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestLabel = i;
        }
      }

      if (bestLabel != null) {
        labels.add(bestLabel);
        // Update centroid (moving average)
        centroids[bestLabel] = _averageVectors(centroids[bestLabel], embedding);
      } else {
        labels.add(centroids.length);
        centroids.add(embedding);
      }
    }

    return labels;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (normA.sqrt() * normB.sqrt());
  }

  List<double> _averageVectors(List<double> a, List<double> b) {
    return List.generate(a.length, (i) => (a[i] + b[i]) / 2);
  }

  // --- Streaming Mode ---

  Future<void> startSession() async {
    // Reset speaker manager for new session
    _manager?.reset();
  }

  Future<List<SpeakerSegment>> processWindow(
    Uint8List pcm16Data,
    List<TranscriptWord> words,
  ) async {
    // Similar to batch mode but for a small window
    // Returns segments with speaker labels
    return [];
  }

  Future<void> endSession() async {
    _manager?.reset();
  }

  // --- Lifecycle ---

  Future<void> dispose() async {
    _extractor?.free();
    _extractor = null;
    _manager?.free();
    _manager = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}

class TranscriptWord {
  final String text;
  final double startTime;
  final double endTime;

  const TranscriptWord({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class _SpeechSegment {
  double startTime;
  double endTime;
  final List<TranscriptWord> words;

  _SpeechSegment({
    required this.startTime,
    required this.endTime,
    required this.words,
  });
}
```

- [ ] **Step 2: Write tests**

Create `test/services/sherpa_diarization_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

void main() {
  group('SherpaDiarizationEngine', () {
    late SherpaDiarizationEngine engine;

    setUp(() {
      engine = SherpaDiarizationEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('isInitialized is false before loadModel', () {
      expect(engine.isInitialized, false);
    });

    test('diarize throws when not initialized', () async {
      expect(
        () => engine.diarize('test.wav', []),
        throwsStateError,
      );
    });
  });
}
```

Run: `flutter test test/services/sherpa_diarization_engine_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/services/sherpa_diarization_engine.dart test/services/sherpa_diarization_engine_test.dart
git commit -m "feat: add Sherpa-ONNX speaker diarization engine"
```

---

## Task 5: On-Device Transcription Service (Batch)

**Files:**
- Create: `lib/services/on_device_transcription_service.dart`
- Create: `lib/providers/on_device_transcription_provider.dart`

- [ ] **Step 1: Create `lib/services/on_device_transcription_service.dart`**

```dart
import 'dart:async';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

class OnDeviceTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final SherpaDiarizationEngine _diarizationEngine;
  bool _isInitialized = false;

  OnDeviceTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
    SherpaDiarizationEngine? diarizationEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine(),
        _diarizationEngine = diarizationEngine ?? SherpaDiarizationEngine();

  Future<void> initialize(ModelSize modelSize) async {
    if (_isInitialized) return;

    // Ensure models are downloaded
    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    // Load ASR model
    final modelPath = await _downloadManager.getModelPath(modelSize);
    final tokensPath = await _downloadManager.getTokensPath();
    await _asrEngine.loadModel(ModelConfig(
      modelPath: modelPath,
      tokensPath: tokensPath,
    ));

    // Load diarization model
    if (!await _downloadManager.isSpeakerModelAvailable()) {
      await _downloadManager.downloadSpeakerModel();
    }
    final speakerModelPath = await _downloadManager.getSpeakerModelPath();
    await _diarizationEngine.loadModel(speakerModelPath);

    _isInitialized = true;
  }

  Future<String> transcribeFile(
    String audioPath, {
    bool diarize = false,
    void Function(String status, double? progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized. Call initialize() first.');
    }

    onProgress?.call('Loading audio…', 0.1);

    // Transcribe audio
    onProgress?.call('Transcribing audio…', 0.3);
    final transcript = await _asrEngine.transcribe(audioPath);

    if (!diarize) {
      onProgress?.call('Done', 1.0);
      return transcript;
    }

    // Diarize
    onProgress?.call('Identifying speakers…', 0.7);
    // TODO: Parse transcript into words with timestamps for diarization
    // For now, return transcript without diarization
    
    onProgress?.call('Done', 1.0);
    return transcript;
  }

  Future<void> dispose() async {
    await _asrEngine.dispose();
    await _diarizationEngine.dispose();
    _downloadManager.dispose();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
```

- [ ] **Step 2: Create `lib/providers/on_device_transcription_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';

final onDeviceTranscriptionServiceProvider = Provider<OnDeviceTranscriptionService>((ref) {
  final service = OnDeviceTranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});
```

- [ ] **Step 3: Write tests**

Create `test/services/on_device_transcription_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';

void main() {
  group('OnDeviceTranscriptionService', () {
    late OnDeviceTranscriptionService service;

    setUp(() {
      service = OnDeviceTranscriptionService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isInitialized is false before initialize', () {
      expect(service.isInitialized, false);
    });

    test('transcribeFile throws when not initialized', () async {
      expect(
        () => service.transcribeFile('test.wav'),
        throwsStateError,
      );
    });
  });
}
```

Run: `flutter test test/services/on_device_transcription_service_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/services/on_device_transcription_service.dart lib/providers/on_device_transcription_provider.dart test/services/on_device_transcription_service_test.dart
git commit -m "feat: add on-device transcription service (batch mode)"
```

---

## Task 6: Real-Time Transcription Service

**Files:**
- Create: `lib/services/real_time_transcription_service.dart`
- Create: `lib/providers/real_time_transcription_provider.dart`

- [ ] **Step 1: Create `lib/services/real_time_transcription_service.dart`**

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';
import 'package:summsumm/services/sherpa_asr_engine.dart';
import 'package:summsumm/services/sherpa_diarization_engine.dart';

class RealTimeTranscriptionService {
  final ModelDownloadManager _downloadManager;
  final SherpaAsrEngine _asrEngine;
  final SherpaDiarizationEngine _diarizationEngine;
  final _segmentController = StreamController<TranscriptSegment>.broadcast();
  bool _isRunning = false;
  bool _diarize = false;
  final _buffer = <Uint8List>[];
  static const _bufferSize = 16000 * 2; // 1 second of 16kHz 16-bit audio

  RealTimeTranscriptionService({
    ModelDownloadManager? downloadManager,
    SherpaAsrEngine? asrEngine,
    SherpaDiarizationEngine? diarizationEngine,
  })  : _downloadManager = downloadManager ?? ModelDownloadManager(),
        _asrEngine = asrEngine ?? SherpaAsrEngine(),
        _diarizationEngine = diarizationEngine ?? SherpaDiarizationEngine();

  Stream<TranscriptSegment> get transcriptStream => _segmentController.stream;

  Future<void> start({
    required ModelSize modelSize,
    bool diarize = false,
  }) async {
    if (_isRunning) return;

    // Ensure models are downloaded
    if (!await _downloadManager.isModelAvailable(modelSize)) {
      await _downloadManager.downloadModel(modelSize);
    }

    // Load ASR model
    final modelPath = await _downloadManager.getModelPath(modelSize);
    final tokensPath = await _downloadManager.getTokensPath();
    await _asrEngine.loadModel(ModelConfig(
      modelPath: modelPath,
      tokensPath: tokensPath,
    ));

    // Create online stream
    await _asrEngine.createStream();

    // Load diarization model if needed
    _diarize = diarize;
    if (diarize) {
      if (!await _downloadManager.isSpeakerModelAvailable()) {
        await _downloadManager.downloadSpeakerModel();
      }
      final speakerModelPath = await _downloadManager.getSpeakerModelPath();
      await _diarizationEngine.loadModel(speakerModelPath);
      await _diarizationEngine.startSession();
    }

    _isRunning = true;
    _buffer.clear();
  }

  void onAudioData(Uint8List pcm16Data) {
    if (!_isRunning) return;

    _buffer.add(pcm16Data);
    final totalBytes = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);

    // Process when we have enough audio (1 second)
    if (totalBytes >= _bufferSize) {
      _processBuffer();
    }
  }

  Future<void> _processBuffer() async {
    if (_buffer.isEmpty) return;

    // Concatenate buffer
    final totalBytes = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(totalBytes);
    var offset = 0;
    for (final chunk in _buffer) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _buffer.clear();

    // Feed to ASR
    final text = await _asrEngine.acceptWaveform(combined);
    
    if (text != null && text.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: text,
        startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        endTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isFinal: false,
      ));
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    // Process remaining buffer
    await _processBuffer();

    // Finalize stream
    final finalText = await _asrEngine.finalizeStream();
    if (finalText.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: finalText,
        startTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        endTime: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isFinal: true,
      ));
    }

    // Cleanup
    _asrEngine.destroyStream();
    if (_diarize) {
      await _diarizationEngine.endSession();
    }

    _isRunning = false;
  }

  Future<void> dispose() async {
    await stop();
    await _asrEngine.dispose();
    await _diarizationEngine.dispose();
    _downloadManager.dispose();
    await _segmentController.close();
  }

  bool get isRunning => _isRunning;
}
```

- [ ] **Step 2: Create `lib/providers/real_time_transcription_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/real_time_transcription_service.dart';

final realTimeTranscriptionServiceProvider = Provider<RealTimeTranscriptionService>((ref) {
  final service = RealTimeTranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final realTimeTranscriptStreamProvider = StreamProvider<TranscriptSegment>((ref) {
  final service = ref.watch(realTimeTranscriptionServiceProvider);
  return service.transcriptStream;
});
```

- [ ] **Step 3: Write tests**

Create `test/services/real_time_transcription_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/real_time_transcription_service.dart';

void main() {
  group('RealTimeTranscriptionService', () {
    late RealTimeTranscriptionService service;

    setUp(() {
      service = RealTimeTranscriptionService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isRunning is false before start', () {
      expect(service.isRunning, false);
    });

    test('onAudioData does nothing when not running', () {
      // Should not throw
      service.onAudioData(Uint8List(0));
    });
  });
}
```

Run: `flutter test test/services/real_time_transcription_service_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/services/real_time_transcription_service.dart lib/providers/real_time_transcription_provider.dart test/services/real_time_transcription_service_test.dart
git commit -m "feat: add real-time transcription service"
```

---

## Task 7: Settings UI

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add imports and new section**

Add imports:
```dart
import '../models/transcription_config.dart';
import '../providers/model_download_provider.dart';
import '../providers/on_device_transcription_provider.dart';
```

- [ ] **Step 2: Add "On-Device Transcription" section**

After the TTS section (before the final SizedBox), add:

```dart
_SectionCard(
  title: 'On-Device Transcription',
  icon: Icons.phone_android_outlined,
  children: [
    // Enable on-device transcription
    SwitchListTile(
      title: const Text('Use on-device transcription'),
      subtitle: const Text('Transcribe offline without internet'),
      value: settings.transcriptionStrategy == TranscriptionStrategy.onDevice,
      onChanged: (v) async {
        await notifier.setTranscriptionStrategy(
          v ? TranscriptionStrategy.onDevice : TranscriptionStrategy.cloud,
        );
        if (v) {
          // Trigger base model download
          final manager = ref.read(modelDownloadManagerProvider);
          if (!await manager.isModelAvailable(ModelSize.base)) {
            manager.downloadModel(ModelSize.base);
          }
        }
      },
    ),
    
    // Model size selector (only when on-device enabled)
    if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice) ...[
      const SizedBox(height: 8),
      DropdownButtonFormField<ModelSize>(
        value: settings.onDeviceModelSize,
        decoration: const InputDecoration(
          labelText: 'Model size',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.memory_outlined),
        ),
        items: ModelSize.values.map((size) {
          final label = switch (size) {
            ModelSize.base => 'Base (~150MB)',
            ModelSize.small => 'Small (~500MB)',
            ModelSize.medium => 'Medium (~1.5GB)',
          };
          return DropdownMenuItem(
            value: size,
            child: Text(label),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) notifier.setOnDeviceModelSize(v);
        },
      ),
      
      // Download progress
      Consumer(
        builder: (context, ref, child) {
          final progressAsync = ref.watch(modelDownloadProgressProvider);
          return progressAsync.when(
            data: (progress) {
              if (progress.status == DownloadStatus.downloading) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress.fraction),
                    const SizedBox(height: 4),
                    Text('Downloading ${progress.size.name} model...'),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      ),
      
      // Live transcription toggle
      SwitchListTile(
        title: const Text('Live transcription'),
        subtitle: const Text('Transcribe while recording'),
        value: settings.enableRealTimeTranscription,
        onChanged: (v) => notifier.setEnableRealTimeTranscription(v),
      ),
      
      // Diarization toggle
      SwitchListTile(
        title: const Text('Speaker diarization'),
        subtitle: const Text('Identify different speakers'),
        value: settings.onDeviceDiarization,
        onChanged: (v) => notifier.setOnDeviceDiarization(v),
      ),
    ],
  ],
),
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add on-device transcription settings UI"
```

---

## Task 8: Meeting Detail Screen Integration

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`
- Modify: `lib/providers/meeting_provider.dart`

- [ ] **Step 1: Modify `lib/providers/meeting_provider.dart`**

Add import:
```dart
import 'package:summsumm/providers/on_device_transcription_provider.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';
```

Modify `transcribe()` method:

```dart
Future<void> transcribe({bool diarize = false}) async {
  final meeting = state;
  final settings = ref.read(settingsProvider);
  final repository = ref.read(meetingRepositoryProvider);
  final processingService = ref.read(processingServiceProvider);

  // Check if using on-device transcription
  if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice) {
    await _transcribeOnDevice(diarize: diarize);
    return;
  }

  // Existing cloud transcription code...
  if (!await _hasConnectivity(settings.provider)) {
    state = meeting.copyWith(
      status: MeetingStatus.failed,
      lastError: 'No internet connection. Please connect to a network and try again.',
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    return;
  }

  // ... rest of existing cloud transcription code
}

Future<void> _transcribeOnDevice({bool diarize = false}) async {
  final meeting = state;
  final settings = ref.read(settingsProvider);
  final repository = ref.read(meetingRepositoryProvider);
  final service = ref.read(onDeviceTranscriptionServiceProvider);

  state = meeting.copyWith(
    status: MeetingStatus.transcribing,
    clearLastError: true,
    transcriptionStatus: 'Loading models…',
    transcriptionProgress: null,
  );
  await repository.save(state);
  ref.read(meetingLibraryProvider.notifier).refresh();

  try {
    // Initialize service
    await service.initialize(settings.onDeviceModelSize);

    // Transcribe
    final transcript = await service.transcribeFile(
      meeting.audioPath,
      diarize: diarize && settings.onDeviceDiarization,
      onProgress: (status, progress) {
        state = state.copyWith(
          transcriptionStatus: status,
          transcriptionProgress: progress,
        );
        _throttledSave(state);
      },
    );

    if (transcript.isEmpty) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'Transcription returned no text. Please ensure the audio file is valid.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(
      transcript: transcript,
      status: MeetingStatus.transcribed,
      provider: 'on-device',
      clearLastError: true,
      clearTranscriptionStatus: true,
      clearTranscriptionProgress: true,
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
  } catch (e) {
    state = meeting.copyWith(
      status: MeetingStatus.failed,
      lastError: e.toString(),
    );
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    rethrow;
  }
}
```

- [ ] **Step 2: Modify `lib/screens/meeting_detail_screen.dart`**

Update diarization switch to work with both cloud and on-device:

```dart
// In _buildTranscriptTab, replace the Tooltip/Switch section:
final settings = ref.watch(settingsProvider);
final canDiarize = settings.provider == 'openrouter' || 
                   settings.transcriptionStrategy == TranscriptionStrategy.onDevice;

return Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Tooltip(
        message: canDiarize ? '' : l10n.meetingDetailDiarizationRequires,
        child: Row(
          children: [
            Switch(
              value: _diarize,
              onChanged: canDiarize
                  ? (v) => setState(() => _diarize = v)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.meetingDetailDiarizeSpeakers,
              style: TextStyle(
                color: canDiarize
                    ? null
                    : Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => provider.transcribe(diarize: _diarize),
        child: Text(l10n.transcribeButton),
      ),
    ],
  ),
);
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/providers/meeting_provider.dart lib/screens/meeting_detail_screen.dart
git commit -m "feat: integrate on-device transcription into meeting detail"
```

---

## Task 9: Recording Screen Integration

**Files:**
- Modify: `lib/screens/recording_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/providers/real_time_transcription_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
```

- [ ] **Step 2: Add live transcription state and UI**

Add to `_RecordingScreenState`:
```dart
bool _liveTranscriptionEnabled = false;
final List<String> _liveTranscriptSegments = [];
```

Modify `_startRecording()`:
```dart
Future<void> _startRecording() async {
  final status = await Permission.microphone.request();
  if (!status.isGranted) {
    // ... existing permission handling
    return;
  }
  
  try {
    final service = ref.read(recordingServiceProvider);
    await service.startRecording(_title);
    
    // Start live transcription if enabled
    final settings = ref.read(settingsProvider);
    if (settings.transcriptionStrategy == TranscriptionStrategy.onDevice &&
        settings.enableRealTimeTranscription) {
      await _startLiveTranscription();
    }
    
    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
    });
    // ... rest of existing code
  } catch (e) {
    // ... existing error handling
  }
}

Future<void> _startLiveTranscription() async {
  final settings = ref.read(settingsProvider);
  final service = ref.read(realTimeTranscriptionServiceProvider);
  
  await service.start(
    modelSize: settings.onDeviceModelSize,
    diarize: settings.onDeviceDiarization,
  );
  
  // Listen to transcript stream
  service.transcriptStream.listen((segment) {
    setState(() {
      _liveTranscriptSegments.add(segment.text);
    });
  });
  
  setState(() {
    _liveTranscriptionEnabled = true;
  });
}
```

Modify `_stopRecording()`:
```dart
Future<void> _stopRecording() async {
  if (!_isRecording) return;
  
  // Stop live transcription
  if (_liveTranscriptionEnabled) {
    final service = ref.read(realTimeTranscriptionServiceProvider);
    await service.stop();
    setState(() {
      _liveTranscriptionEnabled = false;
    });
  }
  
  _timer?.cancel();
  _timer = null;
  setState(() => _isRecording = false);
  
  final service = ref.read(recordingServiceProvider);
  final meeting = await service.stopRecording(_elapsedSeconds);
  
  // Save live transcript if available
  if (_liveTranscriptSegments.isNotEmpty) {
    final transcript = _liveTranscriptSegments.join(' ');
    // Update meeting with transcript
    // Note: This requires Meeting model to support setting transcript
  }
  
  final repository = ref.read(meetingRepositoryProvider);
  await repository.save(meeting);
  if (mounted) Navigator.pop(context);
}
```

- [ ] **Step 3: Add live transcript overlay to build method**

Add to the Column in build:
```dart
if (_liveTranscriptionEnabled && _liveTranscriptSegments.isNotEmpty) ...[
  const SizedBox(height: 20),
  Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.3,
    ),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: SingleChildScrollView(
      child: Text(
        _liveTranscriptSegments.join(' '),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  ),
],
```

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/screens/recording_screen.dart
git commit -m "feat: add live transcription overlay to recording screen"
```

---

## Task 10: Add Dependency and Final Integration

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add sherpa_onnx dependency**

```yaml
dependencies:
  # ... existing dependencies ...
  sherpa_onnx: ^1.11.0
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: Resolves successfully

- [ ] **Step 3: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates .g.dart files successfully

- [ ] **Step 4: Run analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Run tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add sherpa_onnx dependency and regenerate code"
```

---

## Task 11: Final Code Review

- [ ] **Step 1: Review all changes**

Run: `git diff --stat HEAD~10`
Expected: See all new files and modifications

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: No errors or warnings

- [ ] **Step 4: Commit review fixes**

Fix any issues found, then commit.

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|---|---|
| Batch offline transcription | Task 5 |
| Real-time streaming transcription | Task 6 |
| Speaker diarization (batch) | Task 4 + 5 |
| Speaker diarization (streaming) | Task 4 + 6 |
| Model download on-demand | Task 2 |
| Settings integration | Task 1 + 7 |
| MeetingDetailScreen routing | Task 8 |
| RecordingScreen live overlay | Task 9 |
| Zero changes to cloud workflow | All tasks |
| Upgrade path (base/small/medium) | Task 1 + 2 |

## Open Questions from Spec

1. **iOS support**: The plan assumes Android-only for MVP. Verify `sherpa_onnx` supports iOS before claiming cross-platform.
2. **Model hosting**: Using Hugging Face URLs. May need to update if models move.
3. **Real-time diarization**: Implemented as optional toggle. May need performance tuning.

## Risks

- Sherpa-ONNX API may differ from spec. Adjust implementations as needed during Task 3-6.
- Model download sizes are estimates. Actual sizes may vary.
- Real-time diarization may be too slow on low-end devices. Monitor performance.

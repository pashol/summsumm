import 'dart:typed_data';
import 'package:summsumm/models/transcription_config.dart';

// Stub types for sherpa_onnx speaker embedding — will be replaced when the package is added.
// ignore: constant_identifier_names
const bool _sherpaAvailable = false;

class _SpeakerEmbeddingExtractor {
  _SpeakerEmbeddingExtractor({required dynamic config});
  List<double> compute(List<double> samples) => [];
  void free() {}
}

class _SpeakerEmbeddingManager {
  _SpeakerEmbeddingManager({required _SpeakerEmbeddingExtractor extractor});
  void reset() {}
  void free() {}
}

class _SpeakerEmbeddingExtractorConfig {
  final String model;
  _SpeakerEmbeddingExtractorConfig({required this.model});
}

class SherpaDiarizationEngine {
  _SpeakerEmbeddingExtractor? _extractor;
  _SpeakerEmbeddingManager? _manager;
  bool _isInitialized = false;

  Future<void> loadModel(String modelPath) async {
    if (_isInitialized) return;

    if (!_sherpaAvailable) {
      // Package not yet available — initialize stubbed extractor for API compatibility.
      _extractor = _SpeakerEmbeddingExtractor(config: _SpeakerEmbeddingExtractorConfig(model: modelPath));
      _manager = _SpeakerEmbeddingManager(extractor: _extractor!);
      _isInitialized = true;
      return;
    }

    final config = _SpeakerEmbeddingExtractorConfig(
      model: modelPath,
    );

    _extractor = _SpeakerEmbeddingExtractor(config: config);
    _manager = _SpeakerEmbeddingManager(
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
    return dot / (_sqrt(normA) * _sqrt(normB));
  }

  double _sqrt(double x) => x <= 0 ? 0.0 : x; // Placeholder — replace with dart:math sqrt when package available

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

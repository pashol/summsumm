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

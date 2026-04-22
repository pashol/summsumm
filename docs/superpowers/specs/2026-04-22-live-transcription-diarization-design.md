# Live Transcription and On-Device Diarization Design

**Date:** 2026-04-22
**Status:** Draft

## Overview

Implement true live (real-time) transcription during meeting recording and on-device speaker diarization for the summsumm Flutter app. The live transcription result becomes the final transcript — no re-transcription after recording.

## Goals

1. **Live Transcription**: Stream audio chunks during recording to an on-device ASR model and display transcript text in real-time (1-2s latency)
2. **On-Device Diarization**: After recording stops, run speaker diarization on the saved audio file to identify who spoke when
3. **Minimal Changes**: Only activate when `enableRealTimeTranscription` is on and `transcriptionStrategy` is `onDevice`
4. **Backward Compatibility**: Existing cloud transcription path remains unchanged

## Non-Goals

- Cloud-based live transcription (out of scope — use existing cloud path)
- Speaker labels during live transcription (diarization is post-processing only)
- Real-time diarization (computationally infeasible on mobile)

## Architecture

### Recording Flow

```
User taps "Record"
  ↓
RecordingService.startRecording()
  - Opens FlutterSoundRecorder
  - Starts recording to PCM stream (Codec.pcm16, 16kHz, mono)
  - Creates WAV file writer for persistence
  ↓
RealTimeTranscriptionService.start()
  - Downloads streaming model if needed
  - Initializes OnlineRecognizer
  - Creates OnlineStream
  ↓
Audio Stream Split
  ├─→ WAV file (for persistence + diarization)
  └─→ RealTimeTranscriptionService.onAudioData()
        - Buffers chunks
        - Feeds to OnlineStream.acceptWaveform()
        - Calls OnlineRecognizer.decode()
        - Emits TranscriptSegment to stream
  ↓
RecordingScreen displays live transcript
```

### Post-Recording Flow

```
User taps "Stop"
  ↓
RecordingService.stopRecording()
  - Stops PCM stream
  - Finalizes WAV file
  - Optionally converts WAV → M4A for storage
  ↓
RealTimeTranscriptionService.stop()
  - Final decode on remaining audio
  - Emits final segments
  - Returns complete transcript
  ↓
If diarization enabled:
  SherpaDiarizationEngine.diarize(wavPath, transcript)
    - Downloads segmentation + embedding models if needed
    - Runs OfflineSpeakerDiarization
    - Returns SpeakerSegments with speaker labels
  ↓
Meeting saved with:
  - transcript: full text (with speaker labels if diarized)
  - audioPath: path to audio file
  - status: transcribed
```

## Components

### 1. RecordingService (Modified)

**Changes:**
- Add `StreamController<Uint8List>? _audioStreamController`
- Add `IOSink? _wavFileSink`
- When live transcription enabled:
  - Use `startRecorder(toStream: _audioStreamController.sink, codec: Codec.pcm16, sampleRate: 16000, numChannels: 1)`
  - Write PCM chunks to WAV file simultaneously
- When live transcription disabled (existing behavior):
  - Use `startRecorder(toFile: path, codec: Codec.aacMP4)`

**WAV File Writing:**
- Write WAV header first (44 bytes)
- Append PCM16 chunks as they arrive
- On stop: update header with final file size

### 2. RealTimeTranscriptionService (Rewritten)

**Current:** Stub that buffers audio but never processes it

**New Implementation:**

```dart
class RealTimeTranscriptionService {
  final ModelDownloadManager _downloadManager;
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  final _segmentController = StreamController<TranscriptSegment>.broadcast();
  bool _isRunning = false;
  final _buffer = BytesBuilder();
  
  // Buffer audio for batching (process every 0.5s = 8000 samples = 16000 bytes)
  static const int _chunkSizeBytes = 16000;
  
  Future<void> start({required ModelSize modelSize}) async {
    // Download streaming model
    // Initialize OnlineRecognizer with streaming config
    // Create OnlineStream
  }
  
  void onAudioData(Uint8List pcm16Data) {
    _buffer.add(pcm16Data);
    
    // Process when we have enough data
    while (_buffer.length >= _chunkSizeBytes) {
      final chunk = Uint8List.sublistView(
        _buffer.toBytes(), 0, _chunkSizeBytes
      );
      _processChunk(chunk);
      // Remove processed bytes from buffer
      final remaining = _buffer.toBytes().sublist(_chunkSizeBytes);
      _buffer.clear();
      _buffer.add(remaining);
    }
  }
  
  void _processChunk(Uint8List pcm16Data) {
    final samples = _convertPcm16ToFloat32(pcm16Data);
    _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
    
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }
    
    final result = _recognizer!.getResult(_stream!);
    if (result.text.isNotEmpty) {
      _segmentController.add(TranscriptSegment(
        text: result.text,
        startTime: _currentTime,
        endTime: _currentTime + 0.5,
        isFinal: _recognizer!.isEndpoint(_stream!),
      ));
    }
    
    if (_recognizer!.isEndpoint(_stream!)) {
      _recognizer!.reset(_stream!);
    }
  }
  
  Future<String> stop() async {
    // Process remaining buffer
    // Final decode
    // Return complete transcript
  }
}
```

**Model:** Streaming Zipformer model (language-selectable)
- **English**: `sherpa-onnx-streaming-zipformer-en-20M-2023-02-17` (~20MB)
- **German**: No dedicated German Zipformer streaming model available. Options:
  1. Use English model (will transcribe German with English phonetics — poor quality)
  2. Use `sherpa-onnx-cohere-transcribe-14-lang-int8-2026-04-01` (~120MB) — supports German but is an offline model, not streaming
  3. **Recommended**: Use cloud transcription (OpenAI Whisper) for German until a German streaming model becomes available
- **Config**: `OnlineRecognizerConfig` with `OnlineModelConfig`

**Language Selection:**
- If `AppSettings.language` is 'English' → use English streaming model
- If `AppSettings.language` is 'German' → fallback to English model for live transcription (with warning), use cloud for post-recording
- User can override in settings

### 3. SherpaDiarizationEngine (Rewritten)

**Current:** Stub that returns `[]`

**New Implementation:**

```dart
class SherpaDiarizationEngine {
  sherpa.OfflineSpeakerDiarization? _diarization;
  bool _isInitialized = false;
  
  Future<void> loadModel({
    required String segmentationModelPath,
    required String embeddingModelPath,
  }) async {
    final segmentationConfig = sherpa.OfflineSpeakerSegmentationModelConfig(
      pyannote: sherpa.OfflineSpeakerSegmentationPyannoteModelConfig(
        model: segmentationModelPath,
      ),
    );
    
    final embeddingConfig = sherpa.SpeakerEmbeddingExtractorConfig(
      model: embeddingModelPath,
    );
    
    final clusteringConfig = sherpa.FastClusteringConfig(
      numClusters: -1, // Auto-detect
      threshold: 0.5,
    );
    
    final config = sherpa.OfflineSpeakerDiarizationConfig(
      segmentation: segmentationConfig,
      embedding: embeddingConfig,
      clustering: clusteringConfig,
      minDurationOn: 0.2,
      minDurationOff: 0.5,
    );
    
    _diarization = sherpa.OfflineSpeakerDiarization(config);
    _isInitialized = true;
  }
  
  Future<List<SpeakerSegment>> diarize(String audioPath, List<TranscriptWord> words) async {
    final waveData = sherpa.readWave(audioPath);
    
    final segments = _diarization!.process(samples: waveData.samples);
    
    return segments.map((s) => SpeakerSegment(
      speakerLabel: 'Speaker ${s.speaker + 1}',
      startTime: s.start,
      endTime: s.end,
      text: _extractTextForSegment(words, s.start, s.end),
    )).toList();
  }
}
```

**Models:**
- Segmentation: `sherpa-onnx-pyannote-segmentation-3-0` (~30MB)
- Embedding: `3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx` (~30MB)

### 4. ModelDownloadManager (Extended)

**New Methods:**
- `downloadStreamingModel()` — downloads Zipformer streaming model
- `isStreamingModelAvailable()` — checks if streaming model exists
- `getStreamingModelConfig()` — returns `OnlineModelConfig`
- `downloadSegmentationModel()` — downloads pyannote segmentation model
- `downloadEmbeddingModel()` — downloads speaker embedding model

**Download Policy:**
- Models are downloaded **lazily** when the user first enables the corresponding feature in Settings
- `enableRealTimeTranscription` toggle → triggers streaming model download
- `onDeviceDiarization` toggle → triggers segmentation + embedding model downloads
- Download progress shown in settings UI with cancel option
- If download fails, feature toggle reverts to off with error message
- Models are never auto-downloaded on app startup to respect user data/battery

### 5. Meeting Model (Extended)

**New Fields:**
- `List<SpeakerSegment>? speakerSegments` — diarization results
- `bool wasLiveTranscribed` — flag for live transcription

### 6. OnDeviceTranscriptionService (Modified)

**Changes:**
- When `enableRealTimeTranscription` is true:
  - Skip transcription (already done live)
  - Only run diarization if enabled
- When false:
  - Existing behavior (batch Whisper transcription)

## Data Flow

### Live Transcription State Machine

```
[Idle] → start() → [Initializing] → model loaded → [Listening]
                                        ↓
[Listening] → onAudioData() → [Processing] → emit segment → [Listening]
                                        ↓
[Listening] → stop() → [Finalizing] → return transcript → [Idle]
```

### TranscriptSegment Format

```dart
class TranscriptSegment {
  final String text;
  final double startTime;  // seconds from recording start
  final double endTime;
  final String? speakerLabel;  // null during live, filled after diarization
  final bool isFinal;  // true when endpoint detected
}
```

## UI Changes

### RecordingScreen

**Current:** Shows accumulated text in a scrollable container

**New:**
- Keep existing UI
- Add visual indicator for "live" status (pulsing dot)
- Show partial results in italics, final results in normal text
- Display speaker labels after diarization (in meeting detail)

### MeetingDetailScreen

**New:**
- If speaker segments exist, show transcript with speaker labels:
  ```
  [00:15] Speaker 1: Hello everyone
  [00:18] Speaker 2: Hi, thanks for joining
  ```

## Settings

**Existing settings used:**
- `transcriptionStrategy` — must be `onDevice` to enable live transcription
- `enableRealTimeTranscription` — enables live transcription
- `onDeviceDiarization` — enables post-recording diarization

**New settings:**
- `streamingModelLanguage` — english/german (default: english — german uses english model with warning)
- `compressAudioStorage` — bool (default: false) — converts WAV to M4A after diarization

**Settings UI Flow:**
1. User toggles `enableRealTimeTranscription` ON
2. App checks if streaming model is downloaded
3. If not downloaded → show download dialog with size info (~20MB for English)
4. User confirms → download starts with progress bar
5. On success → toggle stays ON, model cached locally
6. On failure/cancel → toggle reverts to OFF, show error
7. Same flow for `onDeviceDiarization` toggle (~60MB total)
8. If app language is German, show warning: "Live transcription uses English model. For German, use cloud transcription."

## Error Handling

1. **Model download fails**: Show error, fallback to batch transcription after recording
2. **ASR initialization fails**: Show error, continue recording without live transcription
3. **Audio stream error**: Log error, continue recording to file
4. **Diarization fails**: Save transcript without speaker labels

## Performance Considerations

1. **CPU Usage**: Streaming ASR runs continuously during recording — target <30% CPU on mid-range Android
2. **Memory**: OnlineRecognizer + OnlineStream ~100-200MB RAM
3. **Battery**: Continuous ASR is battery-intensive — warn user in settings. Consider adding a "Battery Saver" mode that increases chunk size to 1s (reduces decode frequency by 50%)
4. **Latency**: Target <2s from speech to text display

## Testing Strategy

1. **Unit Tests:**
   - `RealTimeTranscriptionService` chunk processing
   - `SherpaDiarizationEngine` with mock data
   - WAV file writer correctness

2. **Integration Tests:**
   - Full recording → live transcription → diarization flow
   - Model download and caching
   - Error recovery paths

3. **Manual Tests:**
   - 5-minute meeting with 2-3 speakers
   - Background noise handling
   - Battery impact assessment

## Migration Plan

1. **Phase 1**: Implement streaming recording + live transcription
2. **Phase 2**: Implement diarization engine
3. **Phase 3**: UI polish (speaker labels, live indicators)
4. **Phase 4**: Performance optimization

## Open Questions

1. **Audio format for storage**: WAV files are ~10x larger than M4A. For a 1-hour meeting: WAV ≈ 115MB, M4A ≈ 15MB. Decision: Keep WAV for diarization compatibility, but offer optional M4A conversion in settings for storage-constrained devices.
2. **Live transcription with cloud strategy**: Out of scope. Cloud live transcription would require WebSocket streaming to OpenAI/Gemini APIs, which is a separate feature.
3. **Model updates**: Add a `modelVersion` field to downloaded models. Check against a manifest URL on app startup. Re-download if version mismatch.
4. **Speaker count**: Diarization auto-detects speaker count. Should we allow user to specify expected speakers for better accuracy? (Not for MVP)
5. **Language support**: Streaming Zipformer model supports English. German users will use English model for live transcription (with warning) or cloud transcription for better German accuracy. Document this limitation.

## Files to Modify

- `lib/services/recording_service.dart` — Add PCM streaming + WAV writing
- `lib/services/real_time_transcription_service.dart` — Full rewrite
- `lib/services/sherpa_diarization_engine.dart` — Full rewrite
- `lib/services/model_download_manager.dart` — Add streaming model downloads
- `lib/services/on_device_transcription_service.dart` — Skip transcription when live
- `lib/screens/recording_screen.dart` — Live UI indicators
- `lib/screens/meeting_detail_screen.dart` — Speaker label display
- `lib/models/meeting.dart` — Add speakerSegments field
- `lib/models/transcription_config.dart` — Add streaming model config

## New Files

- `lib/services/streaming_asr_engine.dart` — Wrapper for OnlineRecognizer
- `lib/services/wav_writer.dart` — Helper for writing WAV files from PCM stream

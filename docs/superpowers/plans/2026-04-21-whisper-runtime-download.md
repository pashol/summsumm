# Whisper Runtime Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix on-device Whisper model download to use correct GitHub release URLs, extract tar.bz2 archives, and wire up the real sherpa_onnx package for offline transcription.

**Architecture:** Download tar.bz2 archives from GitHub releases, extract using the `archive` package, and use real sherpa_onnx classes for transcription instead of stubbed implementations.

**Tech Stack:** Flutter, sherpa_onnx (^1.11.0), archive (^4.0.9), http, path_provider

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `pubspec.yaml` | Modify | Add `archive` dependency |
| `lib/services/model_download_manager.dart` | Modify | Fix URLs, add tar.bz2 extraction |
| `lib/services/sherpa_asr_engine.dart` | Modify | Wire up real sherpa_onnx package |
| `lib/services/sherpa_diarization_engine.dart` | Modify | Wire up real sherpa_onnx diarization |
| `lib/services/real_time_transcription_service.dart` | Modify | Use real sherpa_onnx streaming ASR |
| `lib/services/on_device_transcription_service.dart` | Modify | Use real sherpa_onnx offline ASR |
| `lib/models/transcription_config.dart` | Modify | Update ModelConfig for encoder/decoder paths |
| `test/services/model_download_manager_test.dart` | Modify | Update tests for new download logic |

---

## Model Size Mapping

| ModelSize enum | Whisper Model | Compressed Size | Extracted Size |
|----------------|---------------|-----------------|----------------|
| `base` | `tiny.en` | ~40 MB | ~150 MB |
| `small` | `base.en` | ~75 MB | ~250 MB |
| `medium` | `small.en` | ~150 MB | ~500 MB |

**Rationale:** `tiny.en` is fastest on mobile, good for testing. Users can upgrade to larger models for better accuracy.

---

### Task 1: Add archive dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add archive package to pubspec.yaml**

Add the `archive` package for tar.bz2 extraction:

```yaml
dependencies:
  # ... existing dependencies ...
  archive: ^4.0.9
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependency resolved successfully

---

### Task 2: Update ModelConfig for encoder/decoder paths

**Files:**
- Modify: `lib/models/transcription_config.dart`

- [ ] **Step 1: Update ModelConfig class**

Replace the existing `ModelConfig` class (lines 19-35) with:

```dart
class WhisperModelConfig {
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;
  final int sampleRate;
  final int featureDim;

  const WhisperModelConfig({
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
    this.sampleRate = 16000,
    this.featureDim = 80,
  });
}
```

Remove the old `ModelConfig` class entirely.

- [ ] **Step 2: Verify no other files reference old ModelConfig**

Run: `grep -r "ModelConfig" lib/`
Expected: Only `WhisperModelConfig` references remain (or none if not used elsewhere yet)

---

### Task 3: Rewrite ModelDownloadManager with correct URLs and extraction

**Files:**
- Modify: `lib/services/model_download_manager.dart`

- [ ] **Step 1: Rewrite the entire file**

Replace the entire file with the new implementation that:
1. Downloads `.tar.bz2` from GitHub releases
2. Extracts using BZip2Decoder + TarDecoder from `archive` package
3. Saves `encoder.int8.onnx`, `decoder.int8.onnx`, and `tokens.txt`
4. Provides `WhisperModelConfig` with paths to all three files

Key URL mappings:
- ModelSize.base → `sherpa-onnx-whisper-tiny.en.tar.bz2`
- ModelSize.small → `sherpa-onnx-whisper-base.en.tar.bz2`
- ModelSize.medium → `sherpa-onnx-whisper-small.en.tar.bz2`

Base URL: `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/`

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors in model_download_manager.dart

---

### Task 4: Wire up real sherpa_onnx in SherpaAsrEngine

**Files:**
- Modify: `lib/services/sherpa_asr_engine.dart`

- [ ] **Step 1: Rewrite SherpaAsrEngine to use real sherpa_onnx**

Remove the stubbed implementation. Import `package:sherpa_onnx/sherpa_onnx.dart` and use:
- `sherpa.initBindings()` to initialize
- `sherpa.OfflineRecognizer` with `OfflineWhisperModelConfig`
- `sherpa.OfflineStream` for transcription
- Call `acceptWaveform(audioPath)` and `decode()`

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors in sherpa_asr_engine.dart

---

### Task 5: Update OnDeviceTranscriptionService

**Files:**
- Modify: `lib/services/on_device_transcription_service.dart`

- [ ] **Step 1: Update service to use new WhisperModelConfig**

Update to call `getModelConfig()` instead of separate path getters.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

---

### Task 6: Update RealTimeTranscriptionService

**Files:**
- Modify: `lib/services/real_time_transcription_service.dart`

- [ ] **Step 1: Simplify for offline-only Whisper**

Whisper is offline-only. Update to buffer audio and note that transcription happens after recording stops, or mark as unsupported.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

---

### Task 7: Update SherpaDiarizationEngine

**Files:**
- Modify: `lib/services/sherpa_diarization_engine.dart`

- [ ] **Step 1: Keep as stub for now**

Diarization requires additional speaker embedding models. Keep the stub for now.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

---

### Task 8: Update tests

**Files:**
- Modify: `test/services/model_download_manager_test.dart`

- [ ] **Step 1: Update tests for new API**

Update path expectations to use new naming scheme:
- `tiny.en-encoder.int8.onnx`
- `tiny.en-decoder.int8.onnx`
- `tiny.en-tokens.txt`

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/model_download_manager_test.dart`
Expected: All tests pass

---

### Task 9: Build and test on device

- [ ] **Step 1: Build release APK**

Run: `flutter build apk --release`
Expected: Build succeeds

- [ ] **Step 2: Install on connected device and test**

1. Enable "Use on-device transcription" in settings
2. Verify model download starts
3. Verify model downloads successfully
4. Start a recording
5. Verify recording starts without error

---

## Notes

1. **Whisper is offline-only**: Real-time transcription requires streaming models (Zipformer), not Whisper.

2. **Model sizes**: Using int8 quantized models for smaller size and faster inference on mobile.

3. **Diarization**: Speaker diarization is not yet implemented. It requires additional models.

# Voice Input for Follow-Up Questions

## Overview
Add voice input capability for follow-up questions using a long-press gesture on the send button. The feature supports:
- **OpenAI Whisper API** (if OpenAI API key is configured).
- **Voxtral-24b-2507** via OpenRouter (if OpenRouter API key is configured).
- **Local speech-to-text** (`speech_to_text` plugin) as fallback.

## Behavior
1. **Long-press the send button** to start recording.
2. **Release to stop** recording and trigger transcription.
3. **Transcribed text** is sent as a follow-up question.
4. **Fallback**: If cloud transcription fails, use local speech-to-text.
5. **Error handling**: Show snackbar on failure and revert to text input.

## UI/UX
- **Microphone icon**: Appears inside the send button during recording.
- **Color shift**: Send button turns red during recording.
- **Tooltip**: "Release to send voice" appears on long-press.
- **Max duration**: 30 seconds (configurable).

## Technical Implementation
### Dependencies
- `flutter_sound`: For audio recording.
- `speech_to_text`: For local transcription.

### Code Changes
1. **`summary_provider.dart`**:
   - Add `askFollowUpWithVoice()` to handle transcription and fallback.
   - Integrate with existing `askFollowUp()`.

2. **`summary_sheet.dart`**:
   - Modify `_FollowUpInput` to support long-press on the send button.
   - Add recording state management.

3. **`ai_service.dart`**:
   - Add `transcribeAudio()` to route requests to Whisper/Voxtral.

4. **Error Handling**:
   - Snackbar for transcription failures.
   - Fallback to local transcription if cloud APIs fail.

## Testing
- Test on **Android/iOS** for consistent behavior.
- Verify transcription accuracy for short/long recordings, background noise, and offline mode.

## Documentation
- Update `README.md` to document the feature.
- Add a note in the settings screen (e.g., "Long-press send to record voice").
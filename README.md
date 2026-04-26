# summsumm

AI Text Summarizer — Powerful Android app that brings AI-powered text summarization directly to your fingertips via Android's share-menu and text-selection, with **offline-first meeting recording and transcription**.

## Why summsumm?

Ever wanted to quickly summarize articles, emails, or lengthy texts without leaving your current app? Just select text anywhere on Android, hit share, and summsumm delivers an instant AI-generated summary. No more copy-pasting between apps or struggling with lengthy articles on the go.

## Features

### Text Summarization
- **Share-menu summarization**: Select text in any app and share to summsumm for instant AI summaries
- **PDF summarization**: Summarize PDF documents directly — AI processes the file inline and generates summaries
- **PDF follow-up**: Ask questions about uploaded PDFs — chat history and file data are re-sent for contextual answers
- **Dual AI providers**: Choose between OpenRouter's diverse model selection or OpenAI's GPT models
- **Text-to-Speech**: Listen to summaries on the go with built-in TTS support — perfect for multitasking
- **Fact Check mode**: Verify claims with the investigative journalist AI prompt that identifies TRUE/FALSE/UNVERIFIED claims with emoji prefixes
- **Streaming summaries**: Watch summaries generate in real-time
- **Voice Input**: Long-press the send button to record a follow-up question. The app transcribes using OpenAI Whisper (if OpenAI API key), Voxtral (if OpenRouter API key), or local speech-to-text as fallback.
- **Customizable**: Select your preferred AI model and adjust summarization style

### Meeting Mode (Offline-First)
- **Record meetings**: Capture audio even when offline
- **Background recording**: Continues while screen is off (foreground service)
- **Transcribe later**: Process recordings when network is available
- **On-Device Transcription**: Offline speech-to-text using Sherpa-ONNX Whisper models — no internet required after initial model download
- **Speaker Diarization**: Automatically identify different speakers in meeting recordings
- **Real-time transcription**: Live transcript display during active recording
- **Summarize**: Generate concise meeting notes with action items
- **Library**: Browse all recorded meetings in one place

## Setup

1. Install the app from GitHub releases or build from source
2. Open the app and navigate to Settings
3. Choose your preferred AI provider (OpenRouter or OpenAI)
4. Enter your API key:
   - **OpenRouter**: Get a free key from [openrouter.ai](https://openrouter.ai)
   - **OpenAI**: Get a key from [platform.openai.com](https://platform.openai.com)
5. Optionally customize the AI model, TTS settings, and transcription preferences

## Usage

### Text Summarization
#### Via Share Menu
1. Select text in any app (browser, news reader, email, etc.)
2. Tap the share button
3. Choose summsumm from the list
4. View the AI-generated summary

#### Via Text Selection (Android 6.0+)
1. Select text in any app
2. Tap the "Summarize" option in the popup menu

#### PDF Summarization
1. Launch summsumm directly (no share intent)
2. Tap the file icon to import a PDF
3. View the AI-generated summary
4. Ask follow-up questions in the chat

### Meeting Recording
1. Launch the app directly (no share intent)
2. Tap the mic button to start recording
3. Stop via notification or in-app button
4. Transcribe and summarize when online (or on-device for offline)

#### Transcription Statuses
When transcribing a meeting, you'll see these status indicators:

| Status | Description |
|--------|-------------|
| **Initializing** | Setting up the transcription pipeline and preparing audio file |
| **Preprocessing** | Running FFmpeg audio enhancement (noise reduction, normalization) for files >10MB |
| **Preparing** | Cutting audio into chunks based on silence detection for efficient processing |
| **Analyzing** | Detecting speech segments and splitting audio at natural pauses |
| **Transcribing** | Sending audio chunks to AI for speech-to-text conversion |
| **Finalizing** | Merging chunk transcripts, fixing timestamps, and ensuring consistent speaker labels |

#### On-Device Transcription
1. Go to Settings → Transcription Strategy
2. Select "On-Device" (requires one-time model download)
3. Choose model size: Base (~75MB), Small (~150MB), or Medium (~450MB)
4. Optionally enable Speaker Diarization for speaker identification
5. Transcribe recordings without internet

## Building from Source

Requirements:
- Flutter 3.27+
- Android SDK
- JDK 17+

```bash
# Clone the repository
git clone https://github.com/pashol/summsumm.git
cd summsumm

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## Tech Stack

- **Framework**: Flutter 3.27+
- **State Management**: Riverpod with code generation
- **Architecture**: Clean Architecture (UI → Providers → Services → Models)
- **HTTP**: http package with SSE support
- **Storage**: SharedPreferences + flutter_secure_storage
- **TTS**: flutter_tts
- **Audio**: flutter_sound for recording/playback
- **FFmpeg**: ffmpeg_kit for audio preprocessing
- **On-Device ASR**: Sherpa-ONNX for offline transcription
- **Connectivity**: connectivity_plus for offline detection

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/               # Data classes
│   ├── app_settings.dart
│   ├── summary_state.dart
│   ├── ai_model.dart
│   ├── chat_message.dart
│   └── meeting.dart        # Meeting model
├── providers/            # Riverpod providers
│   ├── settings_provider.dart
│   ├── summary_provider.dart
│   ├── models_provider.dart
│   ├── meeting_provider.dart
│   ├── meeting_repository_provider.dart
│   └── recording_provider.dart
├── screens/              # UI screens
│   ├── settings_screen.dart
│   ├── summary_sheet.dart
│   ├── meeting_library_screen.dart
│   ├── meeting_detail_screen.dart
│   └── recording_screen.dart
├── services/            # Business logic
│   ├── ai_service.dart
│   ├── tts_service.dart
│   ├── secure_storage_service.dart
│   ├── voice_service.dart
│   ├── meeting_repository.dart
│   ├── recording_service.dart
│   ├── on_device_transcription_service.dart
│   ├── real_time_transcription_service.dart
│   ├── model_download_manager.dart
│   ├── sherpa_asr_engine.dart
│   └── sherpa_diarization_engine.dart
└── widgets/             # Reusable widgets
    ├── glass_card.dart
    └── neumorphic_button.dart
```

## Permissions

- **Microphone**: Required for voice input and meeting recording
- **Foreground Service**: For background meeting recording
- **Wake Lock**: To prevent CPU sleep during recording
- **Notifications**: To show recording controls
- **Storage**: To save meeting recordings

## Privacy

- API keys are stored securely using encrypted storage
- No data is collected or sent to external servers (except to your chosen AI provider)
- Text is processed only for summarization and never stored
- On-device transcription keeps audio completely local

## License

MIT License — feel free to use, modify, and distribute.

## Contributing

Contributions welcome! Please open an issue or submit a pull request on GitHub.

---

Made with ❤️ for efficient information processing
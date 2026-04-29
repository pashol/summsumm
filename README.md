# summsumm

AI Text Summarizer — Powerful Android app that brings AI-powered text summarization directly to your fingertips via Android's share-menu and text-selection, with **offline-first meeting recording and transcription**.

## Why summsumm?

Ever wanted to quickly summarize articles, emails, or lengthy texts without leaving your current app? Just select text anywhere on Android, hit share, and summsumm delivers an instant AI-generated summary. No more copy-pasting between apps or struggling with lengthy articles on the go.

## Features

### Text Summarization

**Share-menu summarization** — The core feature. When you select text in any app (browser, news reader, email client, etc.), tap the share button and select summsumm from the share sheet. The app receives the selected text and sends it to your chosen AI provider for processing. The summary appears in a bottom sheet that overlays your current app, so you never lose context.

**Text selection (Android 6.0+)** — On Android 6.0 and later, selecting text shows a popup menu with a "Summarize" option. This is a faster alternative to the share sheet — tap once and the summary appears immediately. Works system-wide across all apps that support text selection.

**Paste import** — Alternatively, you can paste text directly into the app. Launch summsumm, paste your text into the input field, and get an instant summary.

**PDF summarization** — Tap the file icon in the main screen to import a PDF document. The app uses `syncfusion_flutter_pdf` to extract text from the PDF locally (reduces API costs and keeps data smaller), then sends the extracted text to the AI for summarization. The PDF is processed inline using base64 encoding with the `type: "file"` format supported by OpenRouter and OpenAI. No need to copy-paste — just pick your document and get a summary.

**PDF follow-up** — After summarizing a PDF, you can ask questions about the content in a chat interface. The chat history and the PDF file data are re-sent with each follow-up question, allowing the AI to provide contextual answers based on both the document and your previous questions. This enables deep exploration of long documents without re-uploading.

**Dual AI providers** — Summsumm supports two AI backends:

- **OpenRouter** — Aggregates hundreds of AI models from multiple providers. Offers model flexibility, competitive pricing, and frequently updated model listings. The app fetches the available model list dynamically from the OpenRouter API, so you'll always see the latest options. Requires HTTP-Referer and X-Title headers in API calls.
- **OpenAI** — Direct access to GPT models. Simpler API structure with no extra headers required. Static model list (gpt-5.4-nano, gpt-5.4-mini, gpt-5.4) that's always available regardless of API status.

The provider is selectable in Settings, and each provider stores its own API key separately in encrypted storage. You can switch providers anytime — the app remembers both keys.

**Text-to-Speech (TTS)** — Built-in TTS lets you listen to summaries on the go. The app uses `flutter_tts` with language-specific voice configurations. When you tap the speaker icon, the summary is stripped of markdown formatting (headers, bold, links) and spoken aloud. TTS settings include language selection and speech rate control. The app remembers your last-used language and speed settings between sessions.

**Fact Check mode** — Toggle this mode to verify claims in the summarized text. When enabled, the AI uses an investigative journalist prompt that analyzes each claim and marks it as TRUE (✅), FALSE (❌), or UNVERIFIED (🤔) with emoji prefixes. Useful for news articles, research papers, or any content where accuracy matters. The mode works by prefixing the summary prompt with specific instructions for claim verification.

**Streaming summaries** — Summaries appear in real-time as the AI generates them, rather than waiting for the complete response. This uses Server-Sent Events (SSE) via the `http` package. You watch the summary being typed out character-by-character, which provides faster perceived response time and lets you stop generation early if needed.

**Voice Input** — Long-press the send button to record a voice message. The app transcribes your speech and sends it as text. The transcription backend depends on your AI provider:

- OpenAI API key → uses OpenAI Whisper API
- OpenRouter API key → uses Voxtral (OpenRouter's Whisper alternative)
- No valid API key → falls back to device-local `speech_to_text` package

This enables hands-free follow-up questions without typing.

**Customizable models and styles** — In Settings, you can select your preferred AI model from the available list. Each provider shows different models with varying capabilities and pricing. You can also adjust how the summary is generated (detail level, length preferences) by customizing the system prompt.

### Meeting Mode (Offline-First)

Summsumm includes a complete meeting recording and transcription system designed to work without constant internet connectivity.

**Background recording** — Tap the microphone button to start recording. The app runs as a foreground service with a persistent notification, allowing recording to continue even when the screen is off or you switch to another app. The notification includes stop/pause controls for quick access. The app uses `flutter_sound` for audio capture and manages the recording lifecycle across app states.

**Offline-first architecture** — Audio is always saved locally first. You can record meetings anywhere — in airplane mode, underground, or in areas with poor connectivity. Transcription happens later, either via cloud AI (when online) or on-device (always available). This ensures you never lose a recording due to connectivity issues.

**On-Device Transcription** — Summsumm can transcribe audio entirely offline using Sherpa-ONNX Whisper models:

- **Strategy selection** — In Settings, choose between "Cloud" (uses AI API) or "On-Device" (uses local Whisper models)
- **Model sizes** — Three options balance quality vs. download size:
  - Base (~75MB) — Fast, reasonable accuracy for clear audio
  - Small (~150MB) — Better accuracy, still quick
  - Medium (~450MB) — Best accuracy, longer processing time
- **First-time download** — Models are downloaded on-demand from HuggingFace when you first use on-device transcription, then cached locally in `getApplicationDocumentsDirectory()/sherpa_models/`
- **No internet required** — After the initial model download, transcription works completely offline

The on-device transcription uses the `rag_engine_flutter` package for fast neural network inference. For very large audio files (>10MB), the app runs FFmpeg preprocessing first to normalize volume and reduce noise, improving transcription accuracy.

**Speaker Diarization** — When enabled, the app attempts to identify and label different speakers in the recording. This uses embedding-based clustering in the SherpaDiarizationEngine. Requires an additional speaker embedding model download (toggleable in settings). The transcript shows speaker labels like "Speaker 1:", "Speaker 2:", etc.

**Real-time transcription** — During active recording, you can enable live transcript display. The app processes audio in chunks and shows partial transcription as you speak. This uses a streaming ASR approach via SherpaAsrEngine. Note: real-time transcription requires the on-device model and may impact recording performance on lower-end devices.

**Transcription pipeline** — When you transcribe a meeting, the app shows progress through these stages:

| Stage | What happens |
|-------|---------------|
| **Initializing** | Loading audio file, preparing the transcription pipeline |
| **Preprocessing** | FFmpeg enhancement (noise reduction, normalization) for files >10MB |
| **Preparing** | Splitting audio into chunks based on silence detection for efficient processing |
| **Analyzing** | Detecting speech segments and determining split points at natural pauses |
| **Transcribing** | Processing audio chunks through Whisper (cloud or on-device) |
| **Finalizing** | Merging chunk transcripts, fixing timestamps, ensuring consistent speaker labels |

**Meeting Library** — All recorded meetings are stored locally and listed in the Meeting Library screen. Each meeting shows title (auto-generated from date/time), duration, transcription status, and date. You can search and filter meetings, delete old recordings, and access detailed transcripts.

**Meeting Types** — Meetings can be of two types:
- **Audio recordings** — Traditional meeting recordings captured via the microphone
- **Documents** — PDFs or other documents imported for summarization (stored as `MeetingType.document`)

**Archived meetings** — Meetings can be archived to hide them from the main library view without deleting. Archived meetings can be restored or permanently deleted later.

**Chat with meetings** — Each meeting with a transcript supports a chat interface. You can ask questions about the meeting content and get AI-powered answers based on the transcript. The chat history persists and can be referenced later.

**Summarize meetings** — After transcription, you can generate a summary of the meeting. The AI creates concise meeting notes with key discussion points and action items. This uses the same streaming summarization as text summaries, optimized for meeting content.

**Audio playback** — Built-in audio player lets you listen to meeting recordings. Features include play/pause, seek bar with progress tracking, and playback speed control. The player shows current position and total duration.

### Mobile RAG (On-Device AI Search)

Summsumm includes a powerful on-device Retrieval-Augmented Generation (RAG) system that lets you search and ask questions across your entire meeting library.

**How it works** — The app uses `mobile_rag_engine` to build a vector embedding index of all your meeting transcripts and documents. When you ask a question, it searches for relevant passages using hybrid search (combining semantic similarity with keyword matching), then uses the AI to generate an answer based on the retrieved context.

**Hybrid search** — The RAG system combines dense vector embeddings (for semantic understanding) with sparse keyword matching (for precise term lookup). It retrieves the top 12 most relevant chunks with a 3000-token budget, ensuring comprehensive context while staying within AI token limits.

**Offline vector search** — The entire RAG system runs on-device using ONNX models. The embedding model (`model.onnx`) and tokenizer (`tokenizer.json`) are bundled as assets. Index data is stored in a local SQLite database (`library_rag.sqlite`). No internet is required after the initial app installation.

**Chat with Library** — The "Ask Library" feature lets you ask questions that span across all your meetings. For example: "What decisions were made about the budget?" or "When did we discuss the new product launch?" The RAG system finds relevant passages from multiple meetings and the AI synthesizes them into a coherent answer with citations showing which meetings contributed to the response.

**Add to library** — Meeting transcripts are automatically indexed in the RAG system when created. When you import audio files or documents, their text content is also indexed for search.

**Remove from library** — When you delete a meeting, its vector entries are removed from the RAG index.

**Clear all data** — You can reset the entire RAG index from Settings if needed.

### File Import

**Import audio files** — Import existing audio recordings (m4a, mp3, wav, flac, aac, ogg, webm) into the meeting library. The app extracts metadata including duration and stores the audio for transcription and playback. Duration is retrieved efficiently using Android's MediaMetadataRetriever (no full decode needed).

**Import PDF documents** — Import PDF files directly into the library. The app extracts text using the RAG engine's built-in text extraction and stores it as a document-type meeting. These can be summarized, searched via RAG, and chatted with.

**Metadata preservation** — Imported files retain their original filename as the meeting title. Audio files get duration metadata; documents get text content extracted.

### Backup & Restore

**Encrypted backups** — Create encrypted backup files containing your meetings, audio, settings, and API keys. Backups use AES-256-GCM encryption with PBKDF2 key derivation (100,000 iterations) for strong security.

**Password protection** — All backups require a password. The password is never stored — it's used to derive the encryption key each time you restore.

**Selective backup** — Choose what to include:
- Settings (provider, model, TTS preferences, etc.)
- API keys (encrypted with your password)
- Meeting metadata
- Audio files (optional, may exceed size limits)

**Size limits** — Individual audio files capped at 100MB; total audio capped at 500MB per backup. This prevents excessively large backup files.

**Restore** — Import a backup file with your password. The app decrypts and extracts the data, importing meetings that don't already exist (by ID). Meetings with matching IDs are skipped to prevent duplicates.

**Backup file format** — `.summsumm` files contain: salt length (4 bytes) + salt + IV + encrypted GZIP-compressed JSON payload. Fully self-contained and portable.

### PDF Export

**Export summaries** — Export meeting summaries to PDF. The export includes title, date, duration, AI provider used, and the full summary content formatted cleanly.

**Export transcripts** — Export full transcripts to PDF with timestamps and speaker labels. Shows all participants identified during diarization.

**Professional formatting** — PDFs use A4 portrait layout with 2.2cm margins, Helvetica font, page numbers in the footer, and clean metadata headers. Markdown formatting is stripped appropriately for each content type.

### Localization

**Multi-language UI** — Summsumm supports English and German. The app follows your system locale by default, with an option to override in Settings.

**Date/time formatting** — Dates and times are formatted according to your locale settings.

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
5. Optionally use TTS to listen, toggle Fact Check mode, or ask follow-up questions

#### Via Text Selection (Android 6.0+)
1. Select text in any app
2. Tap the "Summarize" option in the popup menu

#### Via Paste
1. Launch summsumm directly
2. Paste text into the input field
3. Tap send to get a summary

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

### Ask the Library
1. Go to the Meeting Library
2. Tap "Ask Library" or the search icon
3. Type a question spanning multiple meetings
4. Get AI answers with citations to relevant meetings

### Backup
1. Go to Settings → Backup
2. Choose what to include (settings, API keys, audio)
3. Set a password
4. Save the `.summsumm` file to your preferred location

## Building from Source

Requirements:
- Flutter 3.27+
- Android SDK
- JDK 17+ (must be full JDK, not JRE-only)

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

**Note**: The first release build takes 10+ minutes as it compiles native components. Subsequent builds are faster (~5-8 minutes). For faster repeat builds, use the cached RAG engine artifacts:

```bash
./scripts/build_release_apk_with_rag_cache.sh
```

## Tech Stack

- **Framework**: Flutter 3.27+ — Cross-platform UI toolkit
- **State Management**: Riverpod with code generation — Reactive state using `@riverpod` annotations and `build_runner` for code generation
- **Architecture**: Clean Architecture — Separation into UI (screens) → Providers → Services → Models
- **HTTP**: http package with SSE support — For streaming AI responses
- **Storage**: SharedPreferences (settings) + flutter_secure_storage (API keys)
- **TTS**: flutter_tts — Text-to-speech with multi-language support
- **Audio**: flutter_sound — Recording and playback
- **FFmpeg**: ffmpeg_kit_flutter_new_audio — Audio preprocessing (noise reduction, normalization)
- **On-Device ASR**: Sherpa-ONNX (via rag_engine_flutter) — Offline speech-to-text
- **Mobile RAG**: mobile_rag_engine — On-device vector search and text extraction
- **PDF**: syncfusion_flutter_pdf — Local PDF text extraction and PDF export
- **Encryption**: encrypt — AES-256-GCM backup encryption
- **Compression**: archive — GZIP compression for backup files
- **Connectivity**: connectivity_plus — Network state detection

## Project Structure

```
lib/
├── main.dart                    # App entry point, intent handling, routing
├── models/                      # Data classes
│   ├── app_settings.dart        # User preferences, provider config, TTS settings, locale
│   ├── summary_state.dart       # Summary screen state (loading, content, error)
│   ├── ai_model.dart            # AI model definitions with pricing info
│   ├── chat_message.dart        # Chat message structure (user/AI, timestamps)
│   ├── meeting.dart             # Meeting model (audio path, transcript, status, type)
│   └── backup_data.dart         # Backup file structure
├── providers/                   # Riverpod providers (code-gen with build_runner)
│   ├── settings_provider.dart   # App settings state and persistence
│   ├── summary_provider.dart    # Summary generation and chat state
│   ├── models_provider.dart     # Available AI models from OpenRouter
│   ├── meeting_provider.dart    # Meeting list and operations
│   ├── meeting_library_provider.dart  # Meeting library with search
│   ├── meeting_chat_provider.dart     # Chat with individual meetings
│   ├── meeting_repository_provider.dart  # Local meeting storage
│   ├── recording_provider.dart  # Active recording state
│   ├── library_rag_provider.dart     # RAG search and index management
│   ├── ask_library_chat_provider.dart  # Chat with entire library
│   ├── backup_service_provider.dart  # Backup/restore operations
│   ├── import_service_provider.dart   # File import service
│   └── locale_provider.dart     # Locale resolution
├── screens/                     # UI screens
│   ├── settings_screen.dart     # Settings UI (provider, model, TTS, transcription, backup)
│   ├── summary_sheet.dart       # Bottom sheet for summary/chat display
│   ├── meeting_library_screen.dart   # List of all recorded meetings + Ask Library
│   ├── meeting_detail_screen.dart    # Meeting view with transcript, summary, chat
│   ├── recording_screen.dart    # Active recording UI with real-time transcript
│   └── archived_meetings_screen.dart  # Archived meetings management
├── services/                    # Business logic
│   ├── ai_service.dart          # AI API calls, streaming, provider routing
│   ├── tts_service.dart         # Text-to-speech with language/speed memory
│   ├── secure_storage_service.dart   # Encrypted API key storage
│   ├── voice_service.dart       # Voice input transcription
│   ├── meeting_repository.dart  # Local file storage for meetings
│   ├── recording_service.dart   # Foreground recording service
│   ├── on_device_transcription_service.dart  # Sherpa-ONNX batch transcription
│   ├── real_time_transcription_service.dart  # Streaming during recording
│   ├── model_download_manager.dart       # Whisper model downloads
│   ├── sherpa_asr_engine.dart    # ASR inference wrapper
│   ├── sherpa_diarization_engine.dart    # Speaker embedding clustering
│   ├── library_rag_service.dart  # Mobile RAG client wrapper
│   ├── library_rag_repository.dart   # RAG repository with caching
│   ├── library_rag_metadata_store.dart  # Metadata for RAG index
│   ├── import_service.dart       # Audio/PDF file import
│   ├── backup_service.dart       # Encrypted backup/restore
│   ├── pdf_export_service.dart  # PDF export for summaries/transcripts
│   ├── audio_player_service.dart # Audio playback with progress
│   ├── wav_writer.dart          # WAV file writing utility
│   └── streaming_asr_engine.dart # Streaming ASR for real-time transcription
└── widgets/                     # Reusable UI components
    ├── glass_card.dart          # Glassmorphism card design
    └── neumorphic_button.dart   # Soft UI button style
```

## Permissions

- **Microphone** (`RECORD_AUDIO`) — Required for voice input and meeting recording
- **Foreground Service** (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`) — For background meeting recording that continues when app is backgrounded
- **Wake Lock** (`WAKE_LOCK`) — Prevents CPU from sleeping during recording, ensuring audio isn't lost
- **Notification** (`POST_NOTIFICATIONS`) — Shows recording controls and status
- **Storage** (`READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`) — Saves meeting audio files (legacy Android); modern Android uses app-specific directories

## Privacy

- **API keys** are stored using `flutter_secure_storage`, which uses Android Keystore encryption. Keys never leave the device except when making API calls directly to your chosen AI provider.
- **No telemetry** — The app doesn't collect usage data, send analytics, or communicate with any servers except the AI providers you explicitly configure.
- **Text processing** — Shared text is processed for summarization only and is not stored. Once the summary is generated, the original text is released from memory.
- **On-device transcription** — When using on-device Whisper, audio stays completely local. Nothing is sent to any server during transcription.
- **Mobile RAG** — All vector embeddings and search happen on-device. No data leaves your phone for the RAG system.
- **Meeting recordings** — Audio is stored only in your app's private directory. You can delete meetings to remove the data.

## License

MIT License — Feel free to use, modify, and distribute.

## Contributing

Contributions welcome! Please open an issue or submit a pull request on GitHub.

---

Made with ❤️ for efficient information processing
# summsumm

AI Text Summarizer — Powerful Android app that brings AI-powered text summarization directly to your fingertips via Android's share-menu and text-selection.

## Why summsumm?

Ever wanted to quickly summarize articles, emails, or lengthy texts without leaving your current app? Just select text anywhere on Android, hit share, and summsumm delivers an instant AI-generated summary. No more copy-pasting between apps or struggling with lengthy articles on the go.

## Features

- **Share-menu summarization**: Select text in any app and share to summsumm for instant AI summaries
- **Dual AI providers**: Choose between OpenRouter's diverse model selection or OpenAI's GPT models
- **Text-to-Speech**: Listen to summaries on the go with built-in TTS support — perfect for multitasking
- **Fact Check mode**: Verify claims with the investigative journalist AI prompt that identifies TRUE/FALSE/UNVERIFIED claims
- **Streaming summaries**: Watch summaries generate in real-time
- **Customizable**: Select your preferred AI model and adjust summarization style

## Setup

1. Install the app from GitHub releases or build from source
2. Open the app and navigate to Settings
3. Choose your preferred AI provider (OpenRouter or OpenAI)
4. Enter your API key:
   - **OpenRouter**: Get a free key from [openrouter.ai](https://openrouter.ai)
   - **OpenAI**: Get a key from [platform.openai.com](https://platform.openai.com)
5. Optionally customize the AI model and TTS settings

## Usage

### Via Share Menu
1. Select text in any app (browser, news reader, email, etc.)
2. Tap the share button
3. Choose summsumm from the list
4. View the AI-generated summary

### Via Text Selection (Android 6.0+)
1. Select text in any app
2. Tap the "Summarize" option in the popup menu

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

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/               # Data classes
│   ├── app_settings.dart
│   ├── summary_state.dart
│   ├── ai_model.dart
│   └── chat_message.dart
├── providers/            # Riverpod providers
│   ├── settings_provider.dart
│   ├── summary_provider.dart
│   └── models_provider.dart
├── screens/              # UI screens
│   ├── settings_screen.dart
│   └── summary_sheet.dart
├── services/            # Business logic
│   ├── ai_service.dart
│   ├── tts_service.dart
│   └── secure_storage_service.dart
└── widgets/             # Reusable widgets
    ├── glass_card.dart
    └── neumorphic_button.dart
```

## Privacy

- API keys are stored securely using encrypted storage
- No data is collected or sent to external servers (except to your chosen AI provider)
- Text is processed only for summarization and never stored

## License

MIT License — feel free to use, modify, and distribute.

## Contributing

Contributions welcome! Please open an issue or submit a pull request on GitHub.

---

Made with ❤️ for efficient information processing
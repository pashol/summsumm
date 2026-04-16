# summsumm — Agent Notes

Flutter Android app for AI text summarization via share-menu and text-selection.

## Architecture

**Entry flow**: `main()` → retrieves intent data via `MethodChannel` → decides to show settings or summary sheet → `SystemNavigator.pop()` on dismiss returns to caller.

**Key directories**:
- `lib/screens/` — UI (settings, summary bottom sheet)
- `lib/providers/` — Riverpod state management (code-gen via `riverpod_annotation`)
- `lib/services/` — AI API calls, TTS, secure storage
- `lib/models/` — Data classes (`AppSettings`, `SummaryState`, `AIModel`, `ChatMessage`)
- `test/` — Unit tests for models and services
- `android/app/src/main/kotlin/app/summsumm/MainActivity.kt` — Native intent handling

**State management**: Riverpod with code generation (`@riverpod` / `@Riverpod(keepAlive: true)` annotations + `build_runner`). Settings persist to `SharedPreferences`; API keys use `flutter_secure_storage`.

**Code generation**: After editing providers, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Commands

```bash
flutter run                    # Run on connected device
flutter test                   # Run all tests
flutter analyze                # Lint / type check
dart run build_runner build --delete-conflicting-outputs   # Regenerate .g.dart
flutter build apk --release    # Build release APK
```

**Build requirement**: `JAVA_HOME` must point to a JDK 17+ (not JRE-only). Gradle uses `includeBuild()` for Flutter tools. If `JAVA_HOME` points to Java 8, builds fail silently.

## AI Providers

Dual-provider system selected via `AppSettings.provider` (`'openrouter'` or `'openai'`):

- **OpenRouter**: Dynamic model list fetched from API. Curated list + expandable full list. Endpoint: `openrouter.ai/api/v1/chat/completions`. Requires `HTTP-Referer` and `X-Title` headers.
- **OpenAI**: Static model list (`gpt-5.4-nano`, `gpt-5.4-mini`, `gpt-5.4`). Endpoint: `api.openai.com/v1/chat/completions`. No extra headers.

`AiService.streamCompletion()` and `testConnection()` take a `provider` param to route to the correct endpoint and headers. `AppSettings.activeModel` resolves to `openrouterModel` or `openaiModel` based on `provider`.

API keys are stored per-provider in `flutter_secure_storage` under keys `'openrouter'` and `'openai'`.

## Features

**Summary**: Streams AI-generated summaries via SSE. Fact Check mode uses an investigative journalist prompt identifying TRUE/FALSE/UNVERIFIED claims with emoji prefixes.

**TTS**: `flutter_tts` with per-language codes. `TtsService` strips markdown before speaking. Stores `_lastLanguage`/`_lastSpeed` and re-applies on resume to prevent speed reset.

**Settings**: Provider dropdown switches between OpenRouter/OpenAI. Model dropdown updates dynamically. TTS slider uses `onChanged` for state-only updates and `onChangeEnd` for persistence (avoids jank from `SharedPreferences` writes on every drag frame).

## Android Integration

**Package**: `app.summsumm`

**Native channel**: `app.summsumm/intent`
- `getInitialIntent` → returns `{action, text}`
- `offerSettingsShortcut` → prompts to pin settings shortcut once

**Intent filters** (AndroidManifest.xml):
- `android.intent.action.PROCESS_TEXT` — text selection popup (API 23+)
- `android.intent.action.SEND` — share sheet from other apps
- Custom `app.summsumm.OPEN_SETTINGS` — homescreen shortcut

**Transparent theme**: Activity uses `@style/TransparentTheme`; host scaffold is transparent; only bottom sheet is visible.

**Release signing**: Configure `key.properties` at project root for release builds. Without it, release builds use debug signing.

## Common Pitfalls

- App exits immediately if intent has no text (opens settings instead).
- OpenRouter models require valid API key to populate dropdown.
- Always call `WidgetsFlutterBinding.ensureInitialized()` before native channel calls.
- After modifying providers, must re-run `build_runner` to regenerate `.g.dart` files.
- Release builds require `key.properties` for proper signing; otherwise debug keys are used.
- `AppSettings.activeModel` resolves model based on `provider` field — always use this getter, never read `openrouterModel`/`openaiModel` directly.
- `JAVA_HOME` must point to a full JDK 17+, not a JRE-only install and not Java 8. Gradle will fail silently otherwise.
- `DropdownButtonFormField` uses `initialValue` (not the deprecated `value` parameter).
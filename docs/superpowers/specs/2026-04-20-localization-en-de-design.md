# Localization Design: EN + DE with System Locale + Override

## Overview

Add full localization support to the summsumm Flutter app using Flutter's built-in `gen-l10n` tool. The app will support English (template) and German, defaulting to the device system locale with an override option in Settings.

---

## 1. Infrastructure Setup

### 1.1 pubspec.yaml
- Add `flutter_localizations` SDK dependency
- Add `generate: true` under the `flutter:` section
- `intl` is already present (`^0.19.0`)

### 1.2 l10n.yaml (project root)
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### 1.3 ARB Files
Create `lib/l10n/` directory with:
- `app_en.arb` — template file with `@key` metadata (descriptions, placeholders)
- `app_de.arb` — German translations (same keys, translated values)

---

## 2. MaterialApp Configuration

### 2.1 main.dart
- Import `flutter_localizations` and generated `AppLocalizations`
- Add `localizationsDelegates` to `MaterialApp`:
  - `AppLocalizations.delegate`
  - `GlobalMaterialLocalizations.delegate`
  - `GlobalWidgetsLocalizations.delegate`
  - `GlobalCupertinoLocalizations.delegate`
- Add `supportedLocales: [Locale('en'), Locale('de')]`
- Add `locale` parameter driven by a Riverpod provider (see §3)

### 2.2 'Imported Audio' string in main.dart
- The `'Imported Audio'` fallback string in `main.dart` (lines 80, 235) is created outside the widget tree (in `main()` before `runApp`). It will remain hardcoded as a fallback, but will be localized when the meeting is displayed in the UI (the meeting title is editable via rename).

---

## 3. Locale Resolution & Settings Override

### 3.1 Locale Provider
Create `lib/providers/locale_provider.dart`:
- `localeProvider` — a `StateNotifierProvider<LocaleNotifier, Locale>` 
- On init: reads `AppSettings.localeOverride` — if set, uses it; otherwise uses `WidgetsBinding.instance.platformDispatcher.locale` (system locale)
- Falls back to `Locale('en')` if system locale is neither `en` nor `de`

### 3.2 AppSettings Extension
Add a `localeOverride` field to `AppSettings`:
- Type: `String?` — stores `'en'`, `'de'`, or `null` (null = system default)
- Persists via existing SharedPreferences mechanism
- Default: `null`

### 3.3 Settings UI
Add a **UI language** selector in `settings_screen.dart`:
- Dropdown with options: "System Default", "English", "Deutsch"
- On change: updates `AppSettings.localeOverride` → triggers `localeProvider` → rebuilds `MaterialApp.locale`
- **Important**: This is separate from the existing "Language" dropdown (which controls the AI summary output language via `kSupportedLanguages`). Place the UI language selector in a new "Appearance" or "General" section, above the existing "Summary" section. Label it clearly as "App Language" or "Display Language" to avoid confusion.

### 3.4 MaterialApp Locale Binding
Wrap `MaterialApp` in a `Consumer` that reads `localeProvider` and passes the resolved `Locale` to `MaterialApp.locale`.

---

## 4. String Extraction

### 4.1 Key Naming Convention
`{screenOrFeature}_{element}_{description}` using camelCase. Examples:
- `settings_title` → `settingsTitle`
- `meetingDetail_tabSummary` → `meetingDetail_tabSummary`
- `library_slidableArchive` → `library_slidableArchive`
- `summarySheet_copyButton` → `summarySheet_copyButton`

### 4.2 String Categories & Estimated Counts

| Category | File(s) | ~Count |
|----------|---------|--------|
| App-level | main.dart | 2 |
| Settings | settings_screen.dart | 20+ |
| Library | meeting_library_screen.dart | 15+ |
| Meeting Detail | meeting_detail_screen.dart | 30+ |
| Summary Sheet | summary_sheet.dart | 15+ |
| Recording | recording_screen.dart | 5+ |
| Archive | archived_meetings_screen.dart | 12+ |
| Share Sheet | meeting_share_sheet.dart | 5 |
| Document Carousel | document_carousel.dart | 1 |
| Summary Style | summary_style.dart | 4 |
| Language Names | app_settings.dart (kSupportedLanguages) | 16 |
| Document Title | document_title.dart | 1 |
| **Total** | | **~126** |

### 4.3 Placeholders
Strings with dynamic values use ARB placeholders:
- `"library_importFailed": "Import failed: {error}"` with `@library_importFailed` defining `{error}` as `String`
- `"meetingDetail_duration": "Duration: {duration}"` with `{duration}` as `String`
- `"documentCarousel_fallback": "Doc {index}"` with `{index}` as `int`
- `"meetingDetail_diarizationRequires": "Diarization requires {provider}"` with `{provider}` as `String`

### 4.4 Plurals
No plural forms needed — the app uses generic phrasing ("No items yet", "No archived meetings").

---

## 5. Dynamic Content (Non-ARB Strings)

### 5.1 SummaryStyle Display Names
Replace `SummaryStyle.displayName` getter with an extension method:
```dart
extension SummaryStyleLocalization on SummaryStyle {
  String localizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SummaryStyle.concise: return l10n.styleConcise;
      case SummaryStyle.brief: return l10n.styleBrief;
      case SummaryStyle.detailed: return l10n.styleDetailed;
      case SummaryStyle.structured: return l10n.styleStructured;
    }
  }
}
```

### 5.2 Language Names (kSupportedLanguages)
Add a helper function to get localized language names for the summary language dropdown:
```dart
String localizedLanguageName(BuildContext context, String languageKey) {
  final l10n = AppLocalizations.of(context)!;
  switch (languageKey) {
    case 'Same as input': return l10n.langSameAsInput;
    case 'English': return l10n.langEnglish;
    case 'German': return l10n.langGerman;
    // ... etc for all 16 entries
  }
}
```
This localizes the display names in the summary language selector. The actual string sent to the AI provider (via `langSuffix`) remains in English.

### 5.3 Model Names (kCuratedModels, kOpenAiModels)
Model names (e.g., "GPT-5.4 Nano", "Claude Sonnet 4.6") are proper nouns / product names and will remain in English. No localization needed.

### 5.4 langSuffix Function
The `langSuffix` function in `summary_style.dart` uses the language name in the AI prompt. This is sent to the AI provider and should remain in English (the language name as the AI understands it). No change needed.

---

## 6. ARB File Structure

### app_en.arb (excerpt)
```json
{
  "appTitle": "AI Text Summarizer",
  "@appTitle": { "description": "Application title shown in app bar" },

  "settingsTitle": "Settings",
  "@settingsTitle": { "description": "Settings screen title" },

  "settings_apiKeyLabel": "API Key",
  "@settings_apiKeyLabel": { "description": "Label for API key input field" },

  "library_importFailed": "Import failed: {error}",
  "@library_importFailed": {
    "description": "Snackbar message when file import fails",
    "placeholders": { "error": { "type": "String" } }
  }
}
```

### app_de.arb (excerpt)
```json
{
  "appTitle": "AI Textzusammenfasser",
  "settingsTitle": "Einstellungen",
  "settings_apiKeyLabel": "API-Schlüssel",
  "library_importFailed": "Import fehlgeschlagen: {error}"
}
```

---

## 7. Workflow

### Adding/Modifying Strings
1. Add key to `app_en.arb` (with `@key` metadata)
2. Add German translation to `app_de.arb`
3. Run `flutter gen-l10n` (or `flutter run` auto-generates)
4. Import `app_localizations.dart` and use `AppLocalizations.of(context)!.keyName`

### Code Generation
- `flutter gen-l10n` is separate from `build_runner` — no conflict
- Generated files go to `.dart_tool/flutter_gen/gen_l10n/` (synthetic package)

### Testing
- Existing tests continue to work — they don't exercise localization
- Widget tests that use localized strings need `Localizations` wrapper with `AppLocalizations.delegate`

---

## 8. Files Modified

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `flutter_localizations`, `generate: true` |
| `l10n.yaml` | New file — gen-l10n config |
| `lib/l10n/app_en.arb` | New file — English template |
| `lib/l10n/app_de.arb` | New file — German translations |
| `lib/main.dart` | Add localization delegates, supportedLocales, locale binding |
| `lib/models/app_settings.dart` | Add `localeOverride` field |
| `lib/models/summary_style.dart` | Replace `displayName` with `localizedTitle(BuildContext)` extension |
| `lib/providers/locale_provider.dart` | New file — locale state management |
| `lib/providers/settings_provider.dart` | Update to handle `localeOverride` |
| `lib/screens/settings_screen.dart` | Add language selector dropdown |
| `lib/screens/meeting_detail_screen.dart` | Replace all hardcoded strings |
| `lib/screens/meeting_library_screen.dart` | Replace all hardcoded strings |
| `lib/screens/summary_sheet.dart` | Replace all hardcoded strings |
| `lib/screens/recording_screen.dart` | Replace all hardcoded strings |
| `lib/screens/archived_meetings_screen.dart` | Replace all hardcoded strings |
| `lib/widgets/meeting_share_sheet.dart` | Replace all hardcoded strings |
| `lib/widgets/document_carousel.dart` | Replace all hardcoded strings |
| `lib/utils/document_title.dart` | Replace `'Document'` fallback |

---

## 9. Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| ARB syntax errors break codegen | Run `flutter gen-l10n` after each batch of additions |
| Missing translations cause runtime errors | English is the template — all keys exist there; German must mirror all keys |
| Settings provider regeneration | After modifying `@riverpod` annotations, run `build_runner` |
| Language names in AI prompts | `langSuffix` and AI prompt strings remain in English — only UI strings are localized |
| 'Imported Audio' in main() | Non-widget context; remains as-is. User can rename the meeting later |

# Settings Menu Redesign — Design Spec

**Date:** 2026-04-23  
**Status:** Approved  
**Approach:** Hub + Sub-pages (Option 2)

---

## Problem

The current `SettingsScreen` is 960 lines with 7 inline sections. As the app grows (onboarding, backup, notifications, account), the single-page layout will become overwhelming and hard to navigate.

## Goals

1. **Scalability** — Add new categories without crowding the main screen
2. **Visual clarity** — Group related settings into cards with section headers
3. **Information density** — Complex sections get dedicated pages with room to breathe
4. **Familiar UX** — Match the grouped list / inset grouped card pattern from iOS Settings and Material Design

---

## Architecture

### Hub Screen (`SettingsScreen`)

A scrollable grouped list with 4 sections. Each row is a tappable card with an icon, title, subtitle, and trailing chevron.

**Section: AI & Models**
| Row | Icon | Title | Subtitle (dynamic) | Destination |
|-----|------|-------|-------------------|-------------|
| 1 | `smart_toy_outlined` | AI & Models | "OpenRouter — GPT-5.4 Mini" | `AiModelsScreen` |
| 2 | `key_outlined` | API Connection | "Connected" / "Not configured" | `ApiConnectionScreen` |

**Section: Transcription**
| Row | Icon | Title | Subtitle (dynamic) | Destination |
|-----|------|-------|-------------------|-------------|
| 1 | `phone_android_outlined` | Transcription | "On-device" / "Cloud" | `TranscriptionSettingsScreen` |

**Section: Output**
| Row | Icon | Title | Subtitle (dynamic) | Destination |
|-----|------|-------|-------------------|-------------|
| 1 | `summarize_outlined` | Summary & Language | "Structured — English" | `SummaryLanguageScreen` |
| 2 | `record_voice_over_outlined` | Text-to-Speech | "1.2×" | `TtsSettingsScreen` |

**Section: App**
| Row | Icon | Title | Subtitle (dynamic) | Destination |
|-----|------|-------|-------------------|-------------|
| 1 | `translate_outlined` | App Language | "English" | `AppLanguageScreen` |
| 2 | `cloud_upload_outlined` | Backup & Restore | — | `BackupScreen` (existing) |

### Visual Style

- Cards use `GlassCard` (existing widget) with `BorderRadius.circular(16)` and horizontal padding `16`
- Section header: bold `titleMedium`, `colorScheme.onSurface`, top padding `24`, bottom `8`
- Row inside card: `ListTile` with `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)`
- Icon in a 32×32 rounded container with `colorScheme.primaryContainer` background
- Chevron: `Icons.chevron_right`, `colorScheme.onSurfaceVariant`
- Card spacing between rows: `8`
- Card spacing between sections: `16`

---

## Sub-Pages

### 1. AiModelsScreen

- **Provider dropdown:** OpenRouter vs OpenAI
- **Model dropdown:** Curated list for OpenRouter; static list for OpenAI
- **Advanced model picker:** Expandable search + series groups (extracted from current `_AdvancedModelPicker`)
- Uses standard `Scaffold` with `AppBar`

### 2. ApiConnectionScreen

- **API key input:** `TextField` with visibility toggle and save button
- **Test connection:** Button with loading state + success/error text
- **Provider label:** Dynamic based on selected provider
- Simpler than current in-place setup because it's a dedicated page

### 3. TranscriptionSettingsScreen

- **Strategy toggle:** SwitchListTile "Use on-device transcription"
- **Model management:** Card-based list (Tiny/Base/Small) with download / select / delete actions
- **Download progress:** Inline `LinearProgressIndicator` during download
- **Live transcription:** SwitchListTile (with German warning dialog)
- **Speaker diarization:** SwitchListTile
- All model UI extracted from current inline section

### 4. SummaryLanguageScreen

- **Summary style:** Dropdown (structured, bullet, narrative, etc.)
- **Output language:** Dropdown from `kSupportedLanguages`

### 5. TtsSettingsScreen

- **Speed slider:** `0.5×` to `2.0×` with `onChanged` for state and `onChangeEnd` for persistence
- Current value displayed above slider

### 6. AppLanguageScreen

- **Language options:** System Default, English, German
- Keeps existing dropdown behavior

### 7. BackupScreen

- Already exists at `lib/screens/backup_screen.dart`
- No changes needed; just navigated from the hub

---

## Data Flow

All sub-pages read from and write to the same `settingsProvider` (Riverpod). No new state management needed. Each page watches `ref.watch(settingsProvider)` and calls `ref.read(settingsProvider.notifier).setXxx()` on changes.

---

## Error Handling

- API key test failures: Show inline error text (red) below the test button
- Model download failures: `SnackBar` with retry option
- Missing API key before advanced model picker: Show "Enter API key first" placeholder
- German + live transcription warning: Keep existing `AlertDialog`

---

## Testing

- Unit tests: Verify `AppSettings.copyWith` for each new field path
- Widget tests: Verify navigation from hub to each sub-page
- Widget tests: Verify settings changes persist via `settingsProvider`
- No new test infrastructure needed

---

## Migration Plan

1. Create 6 new screen files under `lib/screens/settings/`
2. Extract existing inline sections into their respective new screens
3. Replace `SettingsScreen` body with the hub grouped list
4. Remove `_SectionCard`, `_AdvancedModelPicker`, `_SeriesGroup` from `SettingsScreen` (move or keep as needed)
5. Update `BackupScreen` navigation path (already uses `Navigator.push`)
6. Run `flutter analyze` and `flutter test`

---

## Future Growth

New categories can be added as new rows in existing sections or new sections:
- **Notifications** → App section
- **Account / Pro** → New "Account" section at top
- **Data Usage / Storage** → New "Storage" section
- **About / Help** → App section

The hub screen stays manageable because each addition is just one row, not an entire inline form.

---

## Files to Create

- `lib/screens/settings/ai_models_screen.dart`
- `lib/screens/settings/api_connection_screen.dart`
- `lib/screens/settings/transcription_settings_screen.dart`
- `lib/screens/settings/summary_language_screen.dart`
- `lib/screens/settings/tts_settings_screen.dart`
- `lib/screens/settings/app_language_screen.dart`

## Files to Modify

- `lib/screens/settings_screen.dart` — Replace body with hub layout

## Files Unchanged

- `lib/screens/backup_screen.dart`
- `lib/models/app_settings.dart`
- `lib/providers/settings_provider.dart`
- `lib/services/ai_service.dart`

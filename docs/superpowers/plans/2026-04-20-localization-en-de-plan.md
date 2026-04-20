# Localization (EN + DE) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full English/German localization to the summsumm Flutter app using Flutter's gen-l10n tool, with system locale default and Settings override.

**Architecture:** Flutter's built-in ARB-based localization with code generation. ~100 strings extracted from 12 files into `app_en.arb` (template) and `app_de.arb` (German). A Riverpod `localeProvider` resolves the active locale from system settings or user override in Settings.

**Tech Stack:** Flutter gen-l10n, ARB files, Riverpod StateNotifierProvider, MaterialApp locale binding

---

### Task 1: Infrastructure Setup (pubspec.yaml + l10n.yaml)

**Files:**
- Modify: `pubspec.yaml:38-48`
- Create: `l10n.yaml`

- [ ] **Step 1: Update pubspec.yaml**

Add `flutter_localizations` SDK dependency and `generate: true`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  # ... rest of existing dependencies unchanged

flutter:
  uses-material-design: true
  generate: true
```

The `flutter_localizations` block goes right after `flutter: sdk: flutter` in dependencies. Add `generate: true` under the `flutter:` section at the bottom.

- [ ] **Step 2: Create l10n.yaml**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

- [ ] **Step 3: Create lib/l10n directory**

```bash
mkdir -p lib/l10n
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml l10n.yaml && git commit -m "feat: add localization infrastructure (l10n.yaml, flutter_localizations)"
```

---

### Task 2: Create app_en.arb (English Template — All Strings)

**Files:**
- Create: `lib/l10n/app_en.arb`

- [ ] **Step 1: Write the complete ARB file**

This file contains ALL user-facing strings. Every key gets an `@key` entry with description. Placeholders use `{param}` syntax with metadata.

```json
{
  "@@locale": "en",

  "appTitle": "AI Text Summarizer",
  "@appTitle": {
    "description": "Application title shown in app bar"
  },

  "settingsTitle": "Settings",
  "@settingsTitle": {
    "description": "Settings screen title"
  },

  "settingsSetupHint": "Set your API key to get started.",
  "@settingsSetupHint": {
    "description": "Hint shown during initial setup"
  },

  "settingsModelSection": "Model",
  "@settingsModelSection": {
    "description": "Model settings section title"
  },

  "settingsProviderLabel": "Provider",
  "@settingsProviderLabel": {
    "description": "Label for AI provider dropdown"
  },

  "settingsOpenRouter": "OpenRouter",
  "@settingsOpenRouter": {
    "description": "OpenRouter provider name"
  },

  "settingsOpenAi": "OpenAI",
  "@settingsOpenAi": {
    "description": "OpenAI provider name"
  },

  "settingsMoreModels": "More models",
  "@settingsMoreModels": {
    "description": "Expandable section to search all OpenRouter models"
  },

  "settingsSearchAllModels": "Search all OpenRouter models",
  "@settingsSearchAllModels": {
    "description": "Subtitle for more models section"
  },

  "settingsEnterKeyFirst": "Enter your API key first to load models.",
  "@settingsEnterKeyFirst": {
    "description": "Message shown when API key is empty and user tries to browse models"
  },

  "settingsApiKeySection": "{provider} API Key",
  "@settingsApiKeySection": {
    "description": "API key section title with provider name",
    "placeholders": {
      "provider": { "type": "String" }
    }
  },

  "settingsApiKeyLabel": "API Key",
  "@settingsApiKeyLabel": {
    "description": "Label for API key input field"
  },

  "settingsSaveKey": "Save Key",
  "@settingsSaveKey": {
    "description": "Button to save API key"
  },

  "settingsTestButton": "Test",
  "@settingsTestButton": {
    "description": "Button to test API connection"
  },

  "settingsConnectionSuccess": "Connection successful!",
  "@settingsConnectionSuccess": {
    "description": "Success message after connection test"
  },

  "settingsEnterApiKeyFirst": "Enter an API key first",
  "@settingsEnterApiKeyFirst": {
    "description": "Error when testing connection without API key"
  },

  "settingsSelectModelFirst": "Select a model first",
  "@settingsSelectModelFirst": {
    "description": "Error when testing connection without model selected"
  },

  "settingsSummarySection": "Summary",
  "@settingsSummarySection": {
    "description": "Summary settings section title"
  },

  "settingsStyleLabel": "Style",
  "@settingsStyleLabel": {
    "description": "Label for summary style dropdown"
  },

  "settingsLanguageLabel": "Language",
  "@settingsLanguageLabel": {
    "description": "Label for summary language dropdown"
  },

  "settingsTtsSection": "Text-to-Speech",
  "@settingsTtsSection": {
    "description": "TTS settings section title"
  },

  "settingsSearchModelsHint": "Search models...",
  "@settingsSearchModelsHint": {
    "description": "Placeholder text for advanced model search field"
  },

  "settingsFailedToLoadModels": "Failed to load models: {error}",
  "@settingsFailedToLoadModels": {
    "description": "Error message when model list fails to load",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "settingsAppLanguageLabel": "App Language",
  "@settingsAppLanguageLabel": {
    "description": "Label for UI language selector in settings"
  },

  "settingsSystemDefault": "System Default",
  "@settingsSystemDefault": {
    "description": "Option to use device system locale"
  },

  "libraryTitle": "Library",
  "@libraryTitle": {
    "description": "Library screen title"
  },

  "libraryImportFile": "Import file",
  "@libraryImportFile": {
    "description": "Tooltip for import file button"
  },

  "libraryArchived": "Archived",
  "@libraryArchived": {
    "description": "Tooltip for archived meetings button"
  },

  "librarySettings": "Settings",
  "@librarySettings": {
    "description": "Tooltip for settings button"
  },

  "libraryNoItems": "No items yet",
  "@libraryNoItems": {
    "description": "Empty state message in library"
  },

  "libraryError": "Error: {error}",
  "@libraryError": {
    "description": "Error message when loading library fails",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "libraryImportFailed": "Import failed: {error}",
  "@libraryImportFailed": {
    "description": "Snackbar message when file import fails",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "libraryShare": "Share",
  "@libraryShare": {
    "description": "Slidable action label for sharing a meeting"
  },

  "libraryRename": "Rename",
  "@libraryRename": {
    "description": "Slidable action label for renaming a meeting"
  },

  "libraryArchive": "Archive",
  "@libraryArchive": {
    "description": "Slidable action label for archiving a meeting"
  },

  "libraryDelete": "Delete",
  "@libraryDelete": {
    "description": "Button/action label for deleting"
  },

  "libraryDeleteDocument": "Delete Document?",
  "@libraryDeleteDocument": {
    "description": "Delete confirmation dialog title for documents"
  },

  "libraryDeleteMeeting": "Delete Meeting?",
  "@libraryDeleteMeeting": {
    "description": "Delete confirmation dialog title for meetings"
  },

  "libraryDeleteDocumentConfirm": "This will permanently delete this document summary.",
  "@libraryDeleteDocumentConfirm": {
    "description": "Delete confirmation dialog content for documents"
  },

  "libraryDeleteMeetingConfirm": "This will permanently delete the recording and all data.",
  "@libraryDeleteMeetingConfirm": {
    "description": "Delete confirmation dialog content for meetings"
  },

  "cancelButton": "Cancel",
  "@cancelButton": {
    "description": "Cancel button label used in dialogs"
  },

  "saveButton": "Save",
  "@saveButton": {
    "description": "Save button label used in dialogs"
  },

  "deleteButton": "Delete",
  "@deleteButton": {
    "description": "Delete button label in confirmation dialogs"
  },

  "libraryRenameMeeting": "Rename Meeting",
  "@libraryRenameMeeting": {
    "description": "Rename dialog title"
  },

  "summarizeButton": "Summarize",
  "@summarizeButton": {
    "description": "Button to start summarization"
  },

  "transcribeButton": "Transcribe",
  "@transcribeButton": {
    "description": "Button to start transcription"
  },

  "retryButton": "Retry",
  "@retryButton": {
    "description": "Button to retry a failed operation"
  },

  "libraryFailedDetails": "Failed — tap for details",
  "@libraryFailedDetails": {
    "description": "Error indicator text in meeting tiles"
  },

  "libraryArchivedSnackbar": "Meeting archived",
  "@libraryArchivedSnackbar": {
    "description": "Snackbar message after archiving a meeting"
  },

  "undoButton": "Undo",
  "@undoButton": {
    "description": "Undo action in snackbar"
  },

  "shareTitle": "Share",
  "@shareTitle": {
    "description": "Share sheet title"
  },

  "shareAudio": "Share Audio",
  "@shareAudio": {
    "description": "Share sheet option to share audio file"
  },

  "shareTranscript": "Share Transcript",
  "@shareTranscript": {
    "description": "Share sheet option to share transcript"
  },

  "shareSummary": "Share Summary",
  "@shareSummary": {
    "description": "Share sheet option to share summary"
  },

  "shareAudioNotFound": "Audio file not found",
  "@shareAudioNotFound": {
    "description": "Snackbar when audio file is missing"
  },

  "meetingDetailTabSummary": "Summary",
  "@meetingDetailTabSummary": {
    "description": "Tab label for summary view"
  },

  "meetingDetailTabTranscript": "Transcript",
  "@meetingDetailTabTranscript": {
    "description": "Tab label for transcript view"
  },

  "meetingDetailTabChat": "Chat",
  "@meetingDetailTabChat": {
    "description": "Tab label for chat view"
  },

  "meetingDetailDuration": "Duration",
  "@meetingDetailDuration": {
    "description": "Metadata row label for meeting duration"
  },

  "meetingDetailRecorded": "Recorded",
  "@meetingDetailRecorded": {
    "description": "Metadata row label for recording date"
  },

  "meetingDetailTranscribedBy": "Transcribed by",
  "@meetingDetailTranscribedBy": {
    "description": "Metadata row label for transcription provider"
  },

  "meetingDetailNoTranscript": "No transcript yet.\nGo to the Transcript tab to transcribe.",
  "@meetingDetailNoTranscript": {
    "description": "Message when meeting has no transcript yet"
  },

  "meetingDetailTranscribing": "Transcribing…",
  "@meetingDetailTranscribing": {
    "description": "Loading text during transcription"
  },

  "meetingDetailSummarizing": "Summarizing…",
  "@meetingDetailSummarizing": {
    "description": "Loading text during summarization"
  },

  "meetingDetailErrorOccurred": "An error occurred",
  "@meetingDetailErrorOccurred": {
    "description": "Fallback error text when no specific error available"
  },

  "meetingDetailGenerateSummary": "Generate Summary",
  "@meetingDetailGenerateSummary": {
    "description": "Dialog title for generating a new summary"
  },

  "meetingDetailGenerateConfirm": "Generate a new summary in {language} with {style} style?",
  "@meetingDetailGenerateConfirm": {
    "description": "Dialog content confirming summary generation parameters",
    "placeholders": {
      "language": { "type": "String" },
      "style": { "type": "String" }
    }
  },

  "meetingDetailGenerate": "Generate",
  "@meetingDetailGenerate": {
    "description": "Button to confirm summary generation"
  },

  "meetingDetailNotRecording": "This is a document, not a recording.\nGo to the Summary tab to process it.",
  "@meetingDetailNotRecording": {
    "description": "Message in transcript tab for document-type meetings"
  },

  "meetingDetailDiarizationRequires": "Diarization requires OpenRouter",
  "@meetingDetailDiarizationRequires": {
    "description": "Tooltip explaining diarization limitation"
  },

  "meetingDetailDiarizeSpeakers": "Diarize speakers",
  "@meetingDetailDiarizeSpeakers": {
    "description": "Switch label for speaker diarization"
  },

  "meetingDetailDocumentContent": "This is the imported document content, not a transcript.",
  "@meetingDetailDocumentContent": {
    "description": "Banner text in transcript tab for document-type meetings"
  },

  "meetingDetailDocumentNotReady": "Document content not available yet.\nGo to the Summary tab to process it.",
  "@meetingDetailDocumentNotReady": {
    "description": "Message in chat tab when document not yet processed"
  },

  "meetingDetailTranscribeFirst": "Transcribe the meeting first to start chatting.",
  "@meetingDetailTranscribeFirst": {
    "description": "Message in chat tab when no transcript exists"
  },

  "meetingDetailChatHint": "Ask about this meeting…",
  "@meetingDetailChatHint": {
    "description": "Placeholder text for chat input field"
  },

  "summarySheetFailedRecording": "Failed to start recording: {error}",
  "@summarySheetFailedRecording": {
    "description": "Snackbar when voice recording fails to start",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "summarySheetFailedVoice": "Failed to process voice input: {error}",
  "@summarySheetFailedVoice": {
    "description": "Snackbar when voice input processing fails",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "summarySheetNoApiKey": "No API key configured. Open Settings first.",
  "@summarySheetNoApiKey": {
    "description": "Snackbar when summary sheet starts without API key"
  },

  "summarySheetCopied": "Copied to clipboard",
  "@summarySheetCopied": {
    "description": "Snackbar after copying text"
  },

  "summarySheetFactCheck": "Fact Check",
  "@summarySheetFactCheck": {
    "description": "Header text and button label for fact check mode"
  },

  "summarySheetAiSummary": "AI Summary",
  "@summarySheetAiSummary": {
    "description": "Header text for normal summary mode"
  },

  "closeButton": "Close",
  "@closeButton": {
    "description": "Close button tooltip in summary sheet"
  },

  "summarySheetCopy": "Copy",
  "@summarySheetCopy": {
    "description": "Copy button label in summary sheet action bar"
  },

  "summarySheetReadAloud": "Read Aloud",
  "@summarySheetReadAloud": {
    "description": "TTS button label when not playing"
  },

  "summarySheetPause": "Pause",
  "@summarySheetPause": {
    "description": "TTS button label when playing"
  },

  "summarySheetResume": "Resume",
  "@summarySheetResume": {
    "description": "TTS button label when paused"
  },

  "summarySheetStop": "Stop",
  "@summarySheetStop": {
    "description": "Stop TTS button label"
  },

  "summarySheetLastFollowUp": "Last follow-up question...",
  "@summarySheetLastFollowUp": {
    "description": "Placeholder when only one follow-up turn remains"
  },

  "summarySheetFollowUpHint": "Ask a follow-up question...",
  "@summarySheetFollowUpHint": {
    "description": "Placeholder for follow-up question input"
  },

  "recordingTitle": "Record Meeting",
  "@recordingTitle": {
    "description": "Recording screen title"
  },

  "stopButton": "Stop",
  "@stopButton": {
    "description": "Button to stop recording or TTS"
  },

  "startButton": "Start",
  "@startButton": {
    "description": "Button to start recording"
  },

  "recordingMicPermission": "Microphone permission is required to record",
  "@recordingMicPermission": {
    "description": "Snackbar when microphone permission is denied"
  },

  "recordingFailedStart": "Failed to start recording: {error}",
  "@recordingFailedStart": {
    "description": "Snackbar when recording fails to start",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "archiveTitle": "Archived Meetings",
  "@archiveTitle": {
    "description": "Archived meetings screen title"
  },

  "archiveError": "Error: {error}",
  "@archiveError": {
    "description": "Error message when loading archived meetings fails",
    "placeholders": {
      "error": { "type": "String" }
    }
  },

  "archiveNoMeetings": "No archived meetings",
  "@archiveNoMeetings": {
    "description": "Empty state in archived meetings screen"
  },

  "archiveRestore": "Restore",
  "@archiveRestore": {
    "description": "Slidable action to restore archived meeting"
  },

  "archiveRestored": "Meeting restored to library",
  "@archiveRestored": {
    "description": "Snackbar after restoring a meeting"
  },

  "carouselDocFallback": "Doc {index}",
  "@carouselDocFallback": {
    "description": "Fallback title for document carousel item without title",
    "placeholders": {
      "index": { "type": "int" }
    }
  },

  "documentFallback": "Document",
  "@documentFallback": {
    "description": "Fallback document title in document_title.dart"
  },

  "styleConcise": "Concise",
  "@styleConcise": {
    "description": "Summary style display name"
  },

  "styleBrief": "Brief",
  "@styleBrief": {
    "description": "Summary style display name"
  },

  "styleDetailed": "Detailed",
  "@styleDetailed": {
    "description": "Summary style display name"
  },

  "styleStructured": "Structured",
  "@styleStructured": {
    "description": "Summary style display name"
  },

  "langSameAsInput": "Same as input",
  "@langSameAsInput": {
    "description": "Summary language option"
  },

  "langEnglish": "English",
  "@langEnglish": {
    "description": "Language display name"
  },

  "langGerman": "German",
  "@langGerman": {
    "description": "Language display name"
  },

  "langFrench": "French",
  "@langFrench": {
    "description": "Language display name"
  },

  "langSpanish": "Spanish",
  "@langSpanish": {
    "description": "Language display name"
  },

  "langItalian": "Italian",
  "@langItalian": {
    "description": "Language display name"
  },

  "langPortuguese": "Portuguese",
  "@langPortuguese": {
    "description": "Language display name"
  },

  "langRussian": "Russian",
  "@langRussian": {
    "description": "Language display name"
  },

  "langChinese": "Chinese",
  "@langChinese": {
    "description": "Language display name"
  },

  "langJapanese": "Japanese",
  "@langJapanese": {
    "description": "Language display name"
  },

  "langKorean": "Korean",
  "@langKorean": {
    "description": "Language display name"
  },

  "langArabic": "Arabic",
  "@langArabic": {
    "description": "Language display name"
  },

  "langHindi": "Hindi",
  "@langHindi": {
    "description": "Language display name"
  },

  "langDutch": "Dutch",
  "@langDutch": {
    "description": "Language display name"
  },

  "langPolish": "Polish",
  "@langPolish": {
    "description": "Language display name"
  },

  "langTurkish": "Turkish",
  "@langTurkish": {
    "description": "Language display name"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/l10n/app_en.arb && git commit -m "feat: add English localization template (app_en.arb)"
```

---

### Task 3: Create app_de.arb (German Translations — All Strings)

**Files:**
- Create: `lib/l10n/app_de.arb`

- [ ] **Step 1: Write the complete German ARB file**

Every key from app_en.arb must be present. No `@key` metadata needed in translation files — only translated values.

```json
{
  "@@locale": "de",

  "appTitle": "KI-Textzusammenfassung",
  "settingsTitle": "Einstellungen",
  "settingsSetupHint": "Lege deinen API-Schlüssel fest, um zu beginnen.",
  "settingsModelSection": "Modell",
  "settingsProviderLabel": "Anbieter",
  "settingsOpenRouter": "OpenRouter",
  "settingsOpenAi": "OpenAI",
  "settingsMoreModels": "Weitere Modelle",
  "settingsSearchAllModels": "Alle OpenRouter-Modelle durchsuchen",
  "settingsEnterKeyFirst": "Gib zuerst deinen API-Schlüssel ein, um Modelle zu laden.",
  "settingsApiKeySection": "{provider} API-Schlüssel",
  "settingsApiKeyLabel": "API-Schlüssel",
  "settingsSaveKey": "Schlüssel speichern",
  "settingsTestButton": "Testen",
  "settingsConnectionSuccess": "Verbindung erfolgreich!",
  "settingsEnterApiKeyFirst": "Zuerst einen API-Schlüssel eingeben",
  "settingsSelectModelFirst": "Zuerst ein Modell auswählen",
  "settingsSummarySection": "Zusammenfassung",
  "settingsStyleLabel": "Stil",
  "settingsLanguageLabel": "Sprache",
  "settingsTtsSection": "Text-to-Speech",
  "settingsSearchModelsHint": "Modelle suchen...",
  "settingsFailedToLoadModels": "Modelle konnten nicht geladen werden: {error}",
  "settingsAppLanguageLabel": "App-Sprache",
  "settingsSystemDefault": "Systemstandard",

  "libraryTitle": "Bibliothek",
  "libraryImportFile": "Datei importieren",
  "libraryArchived": "Archiviert",
  "librarySettings": "Einstellungen",
  "libraryNoItems": "Noch keine Einträge",
  "libraryError": "Fehler: {error}",
  "libraryImportFailed": "Import fehlgeschlagen: {error}",
  "libraryShare": "Teilen",
  "libraryRename": "Umbenennen",
  "libraryArchive": "Archivieren",
  "libraryDelete": "Löschen",
  "libraryDeleteDocument": "Dokument löschen?",
  "libraryDeleteMeeting": "Meeting löschen?",
  "libraryDeleteDocumentConfirm": "Dies wird diese Dokumentzusammenfassung dauerhaft löschen.",
  "libraryDeleteMeetingConfirm": "Dies wird die Aufnahme und alle Daten dauerhaft löschen.",
  "cancelButton": "Abbrechen",
  "saveButton": "Speichern",
  "deleteButton": "Löschen",
  "libraryRenameMeeting": "Meeting umbenennen",
  "summarizeButton": "Zusammenfassen",
  "transcribeButton": "Transkribieren",
  "retryButton": "Wiederholen",
  "libraryFailedDetails": "Fehlgeschlagen — tippen für Details",
  "libraryArchivedSnackbar": "Meeting archiviert",
  "undoButton": "Rückgängig",

  "shareTitle": "Teilen",
  "shareAudio": "Audio teilen",
  "shareTranscript": "Transkript teilen",
  "shareSummary": "Zusammenfassung teilen",
  "shareAudioNotFound": "Audiodatei nicht gefunden",

  "meetingDetailTabSummary": "Zusammenfassung",
  "meetingDetailTabTranscript": "Transkript",
  "meetingDetailTabChat": "Chat",
  "meetingDetailDuration": "Dauer",
  "meetingDetailRecorded": "Aufgenommen",
  "meetingDetailTranscribedBy": "Transkribiert von",
  "meetingDetailNoTranscript": "Noch kein Transkript.\nWechsle zum Transkript-Tab, um zu transkribieren.",
  "meetingDetailTranscribing": "Transkribieren…",
  "meetingDetailSummarizing": "Zusammenfassen…",
  "meetingDetailErrorOccurred": "Ein Fehler ist aufgetreten",
  "meetingDetailGenerateSummary": "Zusammenfassung erstellen",
  "meetingDetailGenerateConfirm": "Eine neue Zusammenfassung in {language} mit {style}-Stil erstellen?",
  "meetingDetailGenerate": "Erstellen",
  "meetingDetailNotRecording": "Dies ist ein Dokument, keine Aufnahme.\nWechsle zum Zusammenfassung-Tab, um es zu verarbeiten.",
  "meetingDetailDiarizationRequires": "Diarisierung erfordert OpenRouter",
  "meetingDetailDiarizeSpeakers": "Sprecher diarisieren",
  "meetingDetailDocumentContent": "Dies ist der importierte Dokumentinhalt, kein Transkript.",
  "meetingDetailDocumentNotReady": "Dokumentinhalt noch nicht verfügbar.\nWechsle zum Zusammenfassung-Tab, um es zu verarbeiten.",
  "meetingDetailTranscribeFirst": "Transkribiere zuerst das Meeting, um zu chatten.",
  "meetingDetailChatHint": "Frage zu diesem Meeting…",

  "summarySheetFailedRecording": "Aufnahme fehlgeschlagen: {error}",
  "summarySheetFailedVoice": "Spracheingabe fehlgeschlagen: {error}",
  "summarySheetNoApiKey": "Kein API-Schlüssel konfiguriert. Öffne zuerst die Einstellungen.",
  "summarySheetCopied": "In die Zwischenablage kopiert",
  "summarySheetFactCheck": "Faktencheck",
  "summarySheetAiSummary": "KI-Zusammenfassung",
  "closeButton": "Schließen",
  "summarySheetCopy": "Kopieren",
  "summarySheetReadAloud": "Vorlesen",
  "summarySheetPause": "Pause",
  "summarySheetResume": "Fortsetzen",
  "summarySheetStop": "Stopp",
  "summarySheetLastFollowUp": "Letzte Folgefrage...",
  "summarySheetFollowUpHint": "Folgefrage stellen...",

  "recordingTitle": "Meeting aufnehmen",
  "stopButton": "Stopp",
  "startButton": "Start",
  "recordingMicPermission": "Mikrofonberechtigung ist zum Aufnehmen erforderlich",
  "recordingFailedStart": "Aufnahme fehlgeschlagen: {error}",

  "archiveTitle": "Archivierte Meetings",
  "archiveError": "Fehler: {error}",
  "archiveNoMeetings": "Keine archivierten Meetings",
  "archiveRestore": "Wiederherstellen",
  "archiveRestored": "Meeting in Bibliothek wiederhergestellt",

  "carouselDocFallback": "Dok {index}",
  "documentFallback": "Dokument",

  "styleConcise": "Prägnant",
  "styleBrief": "Kurz",
  "styleDetailed": "Detailliert",
  "styleStructured": "Strukturiert",

  "langSameAsInput": "Wie Eingabe",
  "langEnglish": "Englisch",
  "langGerman": "Deutsch",
  "langFrench": "Französisch",
  "langSpanish": "Spanisch",
  "langItalian": "Italienisch",
  "langPortuguese": "Portugiesisch",
  "langRussian": "Russisch",
  "langChinese": "Chinesisch",
  "langJapanese": "Japanisch",
  "langKorean": "Koreanisch",
  "langArabic": "Arabisch",
  "langHindi": "Hindi",
  "langDutch": "Niederländisch",
  "langPolish": "Polnisch",
  "langTurkish": "Türkisch"
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/l10n/app_de.arb && git commit -m "feat: add German translations (app_de.arb)"
```

---

### Task 4: Verify Code Generation

**Files:**
- Verify: `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart` (generated)

- [ ] **Step 1: Run flutter gen-l10n**

```bash
flutter gen-l10n
```

Expected: Successful generation with no errors. Output: `Found 2 ARB files, generating localizations...`

If there are errors:
- Missing key in app_de.arb: ensure every key from app_en.arb exists in app_de.arb
- Invalid placeholder: check that `{param}` in value matches `@key` placeholders metadata
- Invalid JSON: check for missing commas, unescaped quotes

- [ ] **Step 2: Commit generated files**

```bash
git add .dart_tool/flutter_gen/ && git commit -m "chore: generate localization files"
```

---

### Task 5: AppSettings localeOverride + Locale Provider

**Files:**
- Modify: `lib/models/app_settings.dart` (add `localeOverride` field)
- Create: `lib/providers/locale_provider.dart`

- [ ] **Step 1: Add localeOverride to AppSettings**

Modify `lib/models/app_settings.dart`. Add `localeOverride` field, update constructor, `copyWith`, `toJson`, `fromJson`, `defaults`, `hashCode`, and `==`:

```dart
import 'dart:convert';

class AppSettings {
  final String provider;
  final String openrouterModel;
  final String openaiModel;
  final String language;
  final String summaryStyle;
  final double ttsSpeed;
  final String openaiKey;
  final String openrouterKey;
  final bool debugMode;
  final String? localeOverride;

  const AppSettings({
    required this.provider,
    required this.openrouterModel,
    required this.openaiModel,
    required this.language,
    required this.summaryStyle,
    required this.ttsSpeed,
    required this.openaiKey,
    required this.openrouterKey,
    this.debugMode = false,
    this.localeOverride,
  });

  factory AppSettings.defaults() => const AppSettings(
        provider: 'openrouter',
        openrouterModel: '',
        openaiModel: '',
        language: 'Same as input',
        summaryStyle: 'structured',
        ttsSpeed: 1.0,
        openaiKey: '',
        openrouterKey: '',
        debugMode: false,
        localeOverride: null,
      );

  AppSettings copyWith({
    String? provider,
    String? openrouterModel,
    String? openaiModel,
    String? language,
    String? summaryStyle,
    double? ttsSpeed,
    String? openaiKey,
    String? openrouterKey,
    bool? debugMode,
    String? localeOverride,
  }) =>
      AppSettings(
        provider: provider ?? this.provider,
        openrouterModel: openrouterModel ?? this.openrouterModel,
        openaiModel: openaiModel ?? this.openaiModel,
        language: language ?? this.language,
        summaryStyle: summaryStyle ?? this.summaryStyle,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        openaiKey: openaiKey ?? this.openaiKey,
        openrouterKey: openrouterKey ?? this.openrouterKey,
        debugMode: debugMode ?? this.debugMode,
        localeOverride: localeOverride ?? this.localeOverride,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'openrouterModel': openrouterModel,
        'openaiModel': openaiModel,
        'language': language,
        'summaryStyle': summaryStyle,
        'ttsSpeed': ttsSpeed,
        'openaiKey': openaiKey,
        'openrouterKey': openrouterKey,
        'debugMode': debugMode,
        'localeOverride': localeOverride,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        provider: json['provider'] as String? ?? 'openrouter',
        openrouterModel: json['openrouterModel'] as String? ?? '',
        openaiModel: json['openaiModel'] as String? ?? '',
        language: json['language'] as String? ?? 'English',
        summaryStyle: json['summaryStyle'] as String? ?? 'structured',
        ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
        openaiKey: json['openaiKey'] as String? ?? '',
        openrouterKey: json['openrouterKey'] as String? ?? '',
        debugMode: json['debugMode'] as bool? ?? false,
        localeOverride: json['localeOverride'] as String?,
      );

  String get activeModel =>
      provider == 'openai' ? openaiModel : openrouterModel;

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.provider == provider &&
        other.openrouterModel == openrouterModel &&
        other.openaiModel == openaiModel &&
        other.language == language &&
        other.summaryStyle == summaryStyle &&
        other.ttsSpeed == ttsSpeed &&
        other.openaiKey == openaiKey &&
        other.openrouterKey == openrouterKey &&
        other.debugMode == debugMode &&
        other.localeOverride == localeOverride;
  }

  @override
  int get hashCode => Object.hash(
        provider,
        openrouterModel,
        openaiModel,
        language,
        summaryStyle,
        ttsSpeed,
        openaiKey,
        openrouterKey,
        debugMode,
        localeOverride,
      );
}
```

Keep `CuratedModel`, `kCuratedModels`, `kOpenAiModels`, `kSupportedLanguages`, and `kLanguageTtsCode` unchanged.

- [ ] **Step 2: Create locale_provider.dart**

```dart
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

final _supportedLocales = [const Locale('en'), const Locale('de')];

class LocaleNotifier extends StateNotifier<Locale> {
  final Ref ref;

  LocaleNotifier(this.ref) : super(const Locale('en')) {
    _init();
  }

  Future<void> _init() async {
    final settings = ref.read(settingsProvider);
    final override = settings.localeOverride;
    if (override != null) {
      for (final locale in _supportedLocales) {
        if (locale.languageCode == override) {
          state = locale;
          return;
        }
      }
    }
    // Fall back to system locale
    final systemLocale = PlatformDispatcher.instance.locale;
    for (final locale in _supportedLocales) {
      if (locale.languageCode == systemLocale.languageCode) {
        state = locale;
        return;
      }
    }
    state = const Locale('en');
  }

  Future<void> setLocaleOverride(String? languageCode) async {
    final notifier = ref.read(settingsProvider.notifier);
    final settings = ref.read(settingsProvider);
    final next = settings.copyWith(localeOverride: languageCode);
    await notifier.persistSettingsDirect(next);

    if (languageCode == null) {
      // Use system locale
      final systemLocale = PlatformDispatcher.instance.locale;
      for (final locale in _supportedLocales) {
        if (locale.languageCode == systemLocale.languageCode) {
          state = locale;
          return;
        }
      }
      state = const Locale('en');
    } else {
      for (final locale in _supportedLocales) {
        if (locale.languageCode == languageCode) {
          state = locale;
          return;
        }
      }
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref),
);
```

- [ ] **Step 3: Add persistSettingsDirect to Settings notifier**

In `lib/providers/settings_provider.dart`, add a method that persists a specific AppSettings instance (needed by locale_provider to persist and trigger locale change):

```dart
  Future<void> persistSettingsDirect(AppSettings s) async {
    state = s;
    await _persist(s);
  }
```

Add it after the `persistSettings()` method.

- [ ] **Step 4: Commit**

```bash
git add lib/models/app_settings.dart lib/providers/locale_provider.dart lib/providers/settings_provider.dart && git commit -m "feat: add locale override support to AppSettings and locale provider"
```

---

### Task 6: main.dart — Localization Setup

**Files:**
- Modify: `lib/main.dart:1-10` (imports), `lib/main.dart:260-275` (MaterialApp)

- [ ] **Step 1: Add imports**

Add these imports at the top of `lib/main.dart`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

Add them after the existing `flutter/material.dart` import.

- [ ] **Step 2: Wrap MaterialApp with Consumer for locale**

Replace the `build` method in `_SummsummAppState` (lines 260-275):

```dart
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'AI Text Summarizer',
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('de'),
          ],
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: widget.openSettings
              ? const SettingsScreen(isInitialSetup: true)
              : widget.documents.isNotEmpty
                  ? _SummarySheetHost(documents: widget.documents)
                  : const MeetingLibraryScreen(),
        );
      },
    );
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart && git commit -m "feat: configure MaterialApp with localization delegates and locale binding"
```

---

### Task 7: SummaryStyle Localization Extension + Language Name Helper

**Files:**
- Modify: `lib/models/summary_style.dart` (add extension method)
- Create: `lib/utils/localized_strings.dart` (language name helper)

- [ ] **Step 1: Add localizedTitle extension to SummaryStyle**

Modify `lib/models/summary_style.dart`. Keep the existing `displayName` getter for backward compatibility (it's used in places that don't have BuildContext yet), and add a new extension:

```dart
enum MeetingType { meeting, document }

enum SummaryStyle {
  concise,
  brief,
  detailed,
  structured;

  String get displayName {
    switch (this) {
      case SummaryStyle.concise:
        return 'Concise';
      case SummaryStyle.brief:
        return 'Brief';
      case SummaryStyle.detailed:
        return 'Detailed';
      case SummaryStyle.structured:
        return 'Structured';
    }
  }

  static List<SummaryStyle> forType(MeetingType type) {
    switch (type) {
      case MeetingType.meeting:
        return [concise, detailed, structured];
      case MeetingType.document:
        return [concise, brief, detailed];
    }
  }
}

extension SummaryStyleLocalization on SummaryStyle {
  String localizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SummaryStyle.concise:
        return l10n.styleConcise;
      case SummaryStyle.brief:
        return l10n.styleBrief;
      case SummaryStyle.detailed:
        return l10n.styleDetailed;
      case SummaryStyle.structured:
        return l10n.styleStructured;
    }
  }
}
```

Add the import at the top:
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Create localized_strings.dart**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/app_settings.dart';

String localizedLanguageName(BuildContext context, String languageKey) {
  final l10n = AppLocalizations.of(context)!;
  switch (languageKey) {
    case 'Same as input':
      return l10n.langSameAsInput;
    case 'English':
      return l10n.langEnglish;
    case 'German':
      return l10n.langGerman;
    case 'French':
      return l10n.langFrench;
    case 'Spanish':
      return l10n.langSpanish;
    case 'Italian':
      return l10n.langItalian;
    case 'Portuguese':
      return l10n.langPortuguese;
    case 'Russian':
      return l10n.langRussian;
    case 'Chinese':
      return l10n.langChinese;
    case 'Japanese':
      return l10n.langJapanese;
    case 'Korean':
      return l10n.langKorean;
    case 'Arabic':
      return l10n.langArabic;
    case 'Hindi':
      return l10n.langHindi;
    case 'Dutch':
      return l10n.langDutch;
    case 'Polish':
      return l10n.langPolish;
    case 'Turkish':
      return l10n.langTurkish;
    default:
      return languageKey;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/models/summary_style.dart lib/utils/localized_strings.dart && git commit -m "feat: add localization helpers for SummaryStyle and language names"
```

---

### Task 8: Settings Screen Localization + Language Selector

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../providers/locale_provider.dart';
import '../utils/localized_strings.dart';
```

- [ ] **Step 2: Replace all hardcoded strings and add language selector**

Replace the entire `_SettingsScreenState.build` method. Key changes:
1. All `Text('...')` → `Text(l10n.keyName)`
2. All `labelText: '...'` → `labelText: l10n.keyName`
3. All `tooltip: '...'` → `tooltip: l10n.keyName`
4. All `hintText: '...'` → `hintText: l10n.keyName`
5. `'Summary'` section title → `l10n.settingsSummarySection`
6. `'Style'` → `l10n.settingsStyleLabel`
7. `'Language'` → `l10n.settingsLanguageLabel`
8. `s.displayName` → `s.localizedTitle(context)`
9. `kSupportedLanguages.map((l) => Text(l))` → `kSupportedLanguages.map((l) => Text(localizedLanguageName(context, l)))`
10. Add new "App Language" section with dropdown before the Summary section
11. `'$providerLabel API Key'` → `l10n.settingsApiKeySection(providerLabel)`
12. `'Failed to load models: $e'` → `l10n.settingsFailedToLoadModels(e.toString())`

The new "App Language" section goes between the API Key section and the Summary section:

```dart
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.settingsAppLanguageLabel,
            icon: Icons.translate_outlined,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: settings.localeOverride,
                decoration: InputDecoration(
                  labelText: l10n.settingsAppLanguageLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.language_outlined),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.settingsSystemDefault),
                  ),
                  const DropdownMenuItem<String?>(
                    value: 'en',
                    child: Text('English'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: 'de',
                    child: Text('Deutsch'),
                  ),
                ],
                onChanged: (v) {
                  ref.read(localeProvider.notifier).setLocaleOverride(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
```

For the SummaryStyle dropdown items, change:
```dart
items: SummaryStyle.values
    .map((s) => DropdownMenuItem(value: s.name, child: Text(s.displayName)))
    .toList(),
```
to:
```dart
items: SummaryStyle.values
    .map((s) => DropdownMenuItem(value: s.name, child: Text(s.localizedTitle(context))))
    .toList(),
```

For the language dropdown items, change:
```dart
items: kSupportedLanguages
    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
    .toList(),
```
to:
```dart
items: kSupportedLanguages
    .map((l) => DropdownMenuItem(value: l, child: Text(localizedLanguageName(context, l))))
    .toList(),
```

Replace all hardcoded strings in the file:
- `'Settings'` → `l10n.settingsTitle`
- `'Set your API key to get started.'` → `l10n.settingsSetupHint`
- `'Model'` → `l10n.settingsModelSection`
- `'Provider'` → `l10n.settingsProviderLabel`
- `'OpenRouter'` / `'OpenAI'` → `l10n.settingsOpenRouter` / `l10n.settingsOpenAi`
- `'More models'` → `l10n.settingsMoreModels`
- `'Search all OpenRouter models'` → `l10n.settingsSearchAllModels`
- `'Enter your API key first to load models.'` → `l10n.settingsEnterKeyFirst`
- `'API Key'` (labelText) → `l10n.settingsApiKeyLabel`
- `'Save Key'` → `l10n.settingsSaveKey`
- `'Test'` → `l10n.settingsTestButton`
- `'Connection successful!'` → `l10n.settingsConnectionSuccess`
- `'Enter an API key first'` → `l10n.settingsEnterApiKeyFirst`
- `'Select a model first'` → `l10n.settingsSelectModelFirst`
- `'Summary'` → `l10n.settingsSummarySection`
- `'Style'` → `l10n.settingsStyleLabel`
- `'Language'` → `l10n.settingsLanguageLabel`
- `'Text-to-Speech'` → `l10n.settingsTtsSection`
- `'Search models...'` → `l10n.settingsSearchModelsHint`

In `_AdvancedModelPickerState.build`:
- `'Failed to load models: $e'` → `l10n.settingsFailedToLoadModels(e.toString())`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart && git commit -m "feat: localize settings screen and add app language selector"
```

---

### Task 9: Meeting Library Screen Localization

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

In `MeetingLibraryScreen.build`:
- `'Library'` → `l10n.libraryTitle`
- `tooltip: 'Import file'` → `tooltip: l10n.libraryImportFile`
- `tooltip: 'Archived'` → `tooltip: l10n.libraryArchived`
- `tooltip: 'Settings'` → `tooltip: l10n.librarySettings`
- `'Error: $e'` → `l10n.libraryError(e.toString())`
- `'No items yet'` → `l10n.libraryNoItems`

In `_importFile`:
- `'Import failed: $e'` → `l10n.libraryImportFailed(e.toString())`

In `_MeetingTile.build`:
- `label: 'Share'` → `label: l10n.libraryShare`
- `label: 'Rename'` → `label: l10n.libraryRename`
- `label: 'Archive'` → `label: l10n.libraryArchive`
- `label: 'Delete'` → `label: l10n.libraryDelete`
- `'Failed — tap for details'` → `l10n.libraryFailedDetails`

In `_archive`:
- `'Meeting archived'` → `l10n.libraryArchivedSnackbar`
- `label: 'Undo'` → `label: l10n.undoButton`

In `_confirmDelete`:
- Dialog title conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocument : l10n.libraryDeleteMeeting`
- Dialog content conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocumentConfirm : l10n.libraryDeleteMeetingConfirm`
- `'Cancel'` → `l10n.cancelButton`
- `'Delete'` → `l10n.deleteButton`

In `_showRenameDialog`:
- `'Rename Meeting'` → `l10n.libraryRenameMeeting`
- `'Cancel'` → `l10n.cancelButton`
- `'Save'` → `l10n.saveButton`

In `_ActionButton.build`:
- `'Summarize'` → `l10n.summarizeButton`
- `'Transcribe'` → `l10n.transcribeButton`
- `'Retry'` → `l10n.retryButton`

Note: `_MeetingTile` is a `ConsumerWidget`, so it has access to `ref` but not directly to `l10n`. Add `final l10n = AppLocalizations.of(context)!;` at the start of the `build` method. Same for `_ActionButton`.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_library_screen.dart && git commit -m "feat: localize meeting library screen"
```

---

### Task 10: Meeting Detail Screen Localization

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localized_strings.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

In `build`:
- Tab labels: `'Summary'` → `l10n.meetingDetailTabSummary`, `'Transcript'` → `l10n.meetingDetailTabTranscript`, `'Chat'` → `l10n.meetingDetailTabChat`
- `tooltip: 'Share'` → `tooltip: l10n.libraryShare`

In `_buildMetadata`:
- `'Duration'` → `l10n.meetingDetailDuration`
- `'Recorded'` → `l10n.meetingDetailRecorded`
- `'Transcribed by'` → `l10n.meetingDetailTranscribedBy`

In `_buildSummaryTab`:
- `'Summarize'` → `l10n.summarizeButton`
- `'No transcript yet.\nGo to the Transcript tab to transcribe.'` → `l10n.meetingDetailNoTranscript`
- `'Transcribing…'` → `l10n.meetingDetailTranscribing`
- `'Summarizing…'` → `l10n.meetingDetailSummarizing`

In `_buildFailedContent`:
- `'An error occurred'` → `l10n.meetingDetailErrorOccurred`
- `'Retry'` → `l10n.retryButton`

In `_buildChipRow`:
- `summary.style.displayName` → `summary.style.localizedTitle(context)`

In `_buildAddControls`:
- `'Style'` (labelText) → `l10n.settingsStyleLabel`
- `'Language'` (labelText) → `l10n.settingsLanguageLabel`
- Style dropdown items: `s.displayName` → `s.localizedTitle(context)`
- Language dropdown items: use `localizedLanguageName(context, l)`
- `'Generate Summary'` → `l10n.meetingDetailGenerateSummary`
- `'Generate a new summary in $language with $style style?'` → `l10n.meetingDetailGenerateConfirm(language, styleDisplayName)` where `styleDisplayName` is the localized style name
- `'Cancel'` → `l10n.cancelButton`
- `'Generate'` → `l10n.meetingDetailGenerate`
- `'Summarize'` (button) → `l10n.summarizeButton`
- `'Cancel'` (text button) → `l10n.cancelButton`

In `_buildTranscriptTab`:
- `'This is a document, not a recording.\nGo to the Summary tab to process it.'` → `l10n.meetingDetailNotRecording`
- `'Diarization requires OpenRouter'` → `l10n.meetingDetailDiarizationRequires`
- `'Diarize speakers'` → `l10n.meetingDetailDiarizeSpeakers`
- `'Transcribe'` → `l10n.transcribeButton`
- `'This is the imported document content, not a transcript.'` → `l10n.meetingDetailDocumentContent`
- `'Retry'` → `l10n.retryButton`

In `_buildChatTab`:
- `'Document content not available yet.\nGo to the Summary tab to process it.'` → `l10n.meetingDetailDocumentNotReady`
- `'Transcribe the meeting first to start chatting.'` → `l10n.meetingDetailTranscribeFirst`
- `'Ask about this meeting…'` (hintText) → `l10n.meetingDetailChatHint`

In `_renameMeeting`:
- `'Rename Meeting'` → `l10n.libraryRenameMeeting`
- `'Cancel'` → `l10n.cancelButton`
- `'Save'` → `l10n.saveButton`

In `_deleteMeeting`:
- Title conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocument : l10n.libraryDeleteMeeting`
- Content conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocumentConfirm : l10n.libraryDeleteMeetingConfirm`
- `'Cancel'` → `l10n.cancelButton`
- `'Delete'` → `l10n.deleteButton`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart && git commit -m "feat: localize meeting detail screen"
```

---

### Task 11: Summary Sheet Localization

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

In `_SummarySheetState`:
- `'Failed to start recording: ${e.toString()}'` → `l10n.summarySheetFailedRecording(e.toString())`
- `'Failed to process voice input: ${e.toString()}'` → `l10n.summarySheetFailedVoice(e.toString())`
- `'No API key configured. Open Settings first.'` → `l10n.summarySheetNoApiKey`
- `'Copied to clipboard'` → `l10n.summarySheetCopied`

In `_SheetBody.build`:
- `tooltip: 'Settings'` → `tooltip: l10n.librarySettings`
- `'Fact Check'` → `l10n.summarySheetFactCheck`
- `'AI Summary'` → `l10n.summarySheetAiSummary`
- `tooltip: 'Close'` → `tooltip: l10n.closeButton`
- `'Retry'` → `l10n.retryButton`

In `_ActionBar.build`:
- `'Read Aloud'` → `l10n.summarySheetReadAloud`
- `'Pause'` → `l10n.summarySheetPause`
- `'Resume'` → `l10n.summarySheetResume`
- `'Stop'` → `l10n.summarySheetStop`
- `'Copy'` → `l10n.summarySheetCopy`
- `'Fact Check'` → `l10n.summarySheetFactCheck`

In `_FollowUpInputState.build`:
- `'Last follow-up question...'` → `l10n.summarySheetLastFollowUp`
- `'Ask a follow-up question...'` → `l10n.summarySheetFollowUpHint`

Note: `_SheetBody`, `_ActionBar`, and `_FollowUpInput` are `StatelessWidget`/`StatefulWidget` — they receive `context` in their `build` method, so `AppLocalizations.of(context)!` works directly.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "feat: localize summary sheet"
```

---

### Task 12: Recording Screen Localization

**Files:**
- Modify: `lib/screens/recording_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

- `'Record Meeting'` → `l10n.recordingTitle`
- `'Stop'` → `l10n.stopButton`
- `'Start'` → `l10n.startButton`
- `'Microphone permission is required to record'` → `l10n.recordingMicPermission`
- `'Failed to start recording: $e'` → `l10n.recordingFailedStart(e.toString())`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/recording_screen.dart && git commit -m "feat: localize recording screen"
```

---

### Task 13: Archived Meetings Screen Localization

**Files:**
- Modify: `lib/screens/archived_meetings_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

In `ArchivedMeetingsScreen.build`:
- `'Archived Meetings'` → `l10n.archiveTitle`
- `'Error: $e'` → `l10n.archiveError(e.toString())`
- `'No archived meetings'` → `l10n.archiveNoMeetings`

In `_ArchivedMeetingTile.build`:
- `label: 'Share'` → `label: l10n.libraryShare`
- `label: 'Restore'` → `label: l10n.archiveRestore`
- `label: 'Delete'` → `label: l10n.libraryDelete`
- `'Failed — tap for details'` → `l10n.libraryFailedDetails`

In `_unarchive`:
- `'Meeting restored to library'` → `l10n.archiveRestored`

In `_confirmDelete`:
- Title conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocument : l10n.libraryDeleteMeeting`
- Content conditional → `meeting.type == MeetingType.document ? l10n.libraryDeleteDocumentConfirm : l10n.libraryDeleteMeetingConfirm`
- `'Cancel'` → `l10n.cancelButton`
- `'Delete'` → `l10n.deleteButton`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/archived_meetings_screen.dart && git commit -m "feat: localize archived meetings screen"
```

---

### Task 14: Share Sheet Localization

**Files:**
- Modify: `lib/widgets/meeting_share_sheet.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace all hardcoded strings**

- `'Share'` (title) → `l10n.shareTitle`
- `'Share Audio'` → `l10n.shareAudio`
- `'Share Transcript'` → `l10n.shareTranscript`
- `'Share Summary'` → `l10n.shareSummary`
- `'Audio file not found'` → `l10n.shareAudioNotFound`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/meeting_share_sheet.dart && git commit -m "feat: localize meeting share sheet"
```

---

### Task 15: Document Carousel + Document Title Localization

**Files:**
- Modify: `lib/widgets/document_carousel.dart`
- Modify: `lib/utils/document_title.dart`

- [ ] **Step 1: Localize document_carousel.dart**

Add import:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

Replace:
```dart
documents[index].title ?? 'Doc ${index + 1}'
```
with:
```dart
documents[index].title ?? AppLocalizations.of(context)!.carouselDocFallback(index + 1)
```

- [ ] **Step 2: Localize document_title.dart**

The `documentTitle` function is called outside the widget tree (in `main.dart` before `runApp` and in `_SummarySheetHost`/`_DocumentSheetHost` initState). We cannot use `AppLocalizations` here. Instead, make the function accept an optional fallback parameter:

```dart
import '../models/document.dart';

String documentTitle(List<Document> docs, {String fallback = 'Document'}) {
  if (docs.isEmpty) return fallback;
  final doc = docs.first;
  if (doc.name != null && doc.name!.isNotEmpty) return doc.name!;
  final text = doc.text.trim();
  if (text.isEmpty) return fallback;
  final firstLine = text.split('\n').first.trim();
  if (firstLine.isEmpty) return fallback;
  return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
}
```

The fallback `'Document'` will remain in English for the initial meeting creation (before the widget tree is built). Once the meeting appears in the library, the user can rename it. This is acceptable per the design spec.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/document_carousel.dart lib/utils/document_title.dart && git commit -m "feat: localize document carousel and title utility"
```

---

### Task 16: Final Verification & Cleanup

**Files:**
- All modified files

- [ ] **Step 1: Run flutter gen-l10n**

```bash
flutter gen-l10n
```

Expected: No errors.

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Fix any issues:
- Missing `BuildContext` in a place where `AppLocalizations.of(context)` is called — pass context as parameter
- Unused imports
- Type mismatches from placeholder parameters

- [ ] **Step 3: Run flutter test**

```bash
flutter test
```

Existing tests should pass. If any widget tests fail because they need `AppLocalizations`, wrap the tested widget in a `Localizations` widget:

```dart
await tester.pumpWidget(
  Localizations(
    locale: const Locale('en'),
    delegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    child: MaterialApp(
      home: WidgetUnderTest(),
    ),
  ),
);
```

- [ ] **Step 4: Final commit**

```bash
git add -A && git commit -m "feat: complete localization — all screens, widgets, and models localized (EN+DE)"
```

---

## Self-Review

**1. Spec coverage check:**
- Infrastructure (pubspec, l10n.yaml, ARB files): Tasks 1-4 ✓
- AppSettings localeOverride + locale provider: Task 5 ✓
- MaterialApp localization config: Task 6 ✓
- SummaryStyle localization: Task 7 ✓
- Language names localization: Task 7 ✓
- Settings screen + language selector: Task 8 ✓
- All 6 screens localized: Tasks 9-13 ✓
- Widgets localized: Tasks 14-15 ✓
- Verification: Task 16 ✓

**2. Placeholder scan:** No TBD, TODO, or vague steps. All steps contain actual code.

**3. Type consistency:**
- `AppLocalizations.of(context)!.keyName` used consistently
- Placeholder methods like `l10n.libraryError(e.toString())` match ARB definitions
- `SummaryStyle.localizedTitle(context)` extension used in all dropdowns
- `localizedLanguageName(context, l)` used for all language dropdowns
- `localeProvider` returns `Locale`, passed to `MaterialApp.locale`

**4. No missing steps:** Every file from the spec's "Files Modified" table is covered.

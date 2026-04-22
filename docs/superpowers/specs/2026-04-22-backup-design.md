# Backup System Design

Encrypted, compressed export/import for settings and meeting data.

## Overview

Users can export their app state (settings, API keys, meeting metadata, optionally audio) to a single encrypted `.summsumm` file. The file is password-protected and portable across devices.

## Data Model

```dart
// lib/models/backup_data.dart
class BackupData {
  final String version;           // "1.0" for future migrations
  final DateTime exportedAt;
  final AppSettings? settings;
  final String? openrouterKey;    // null if not included
  final String? openaiKey;        // null if not included
  final List<Meeting> meetings;   // metadata only (no audio)
  final Map<String, String>? audioFiles; // meetingId -> base64 audio, null if not included
}
```

## Encryption & Compression

**Pipeline:** JSON → gzip → AES-256-GCM → `.summsumm` file

- **Encryption:** `encrypt` package, AES-256-GCM with PBKDF2 key derivation from user password
- **Compression:** `archive` package (already in project for model downloads)
- **Key derivation:** 100,000 iterations PBKDF2 with random salt stored in file header

### File Format

```
[4 bytes: salt length][salt][16 bytes: IV][encrypted payload]
```

## BackupService

```dart
// lib/services/backup_service.dart
class BackupService {
  final MeetingRepository _meetingRepository;
  final SecureStorageService _secureStorage;
  final Settings _settings;
  
  BackupService(this._meetingRepository, this._secureStorage, this._settings);
  
  /// Creates encrypted backup file.
  /// Returns the file for sharing/saving.
  Future<File> export({
    required String password,
    required bool includeSettings,
    required bool includeApiKeys,
    required bool includeAudio,
    required String filename,
  });
  
  /// Imports from encrypted backup file.
  /// Skips meetings that already exist (by ID).
  Future<ImportResult> import({
    required String password,
    required File file,
  });
}

class ImportResult {
  final int meetingsImported;
  final int meetingsSkipped;
  final bool settingsImported;
  final bool apiKeysImported;
  final String? error;
  
  bool get success => error == null;
}
```

### Export Logic

1. Collect data based on flags:
   - If `includeSettings`: serialize current `AppSettings`
   - If `includeApiKeys`: read from `SecureStorageService`
   - Always include meeting metadata from `MeetingRepository.loadAll()`
   - If `includeAudio`: read audio files, encode as base64
2. Create `BackupData` with version "1.0"
3. Serialize to JSON, gzip compress, encrypt with password
4. Write to temp file, return for sharing

### Import Logic

1. Read file, decrypt with password
2. Decompress, parse `BackupData`
3. If settings included: merge with current (imported wins)
4. If API keys included: write to `SecureStorageService`
5. For each meeting: check if ID exists, skip if so, otherwise save
6. Return counts

## UI

### Entry Point

Settings screen → new tile "Backup & Restore" → navigates to `BackupScreen`

### BackupScreen

Single screen with two expandable sections (or tabs):

**Export Section:**
- Checkbox: "Include settings" (default: checked)
- Checkbox: "Include API keys" (default: unchecked, requires settings checkbox)
- Checkbox: "Include meeting data" (default: checked)
- Checkbox: "Include audio files" (default: unchecked, requires meeting data checkbox)
- Text field: Filename (pre-filled with `summsumm_backup_2026-04-22`)
- Button: "Export" → shows password dialog → progress indicator → share sheet

**Import Section:**
- Button: "Select backup file" → file picker
- After file selected: password dialog
- Progress indicator during import
- Result summary: "Imported X meetings, skipped Y duplicates. Settings restored."

### Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  encrypt: ^5.0.3
  file_picker: ^8.0.0
  share_plus: ^7.2.0
```

`archive` and `path_provider` are already in the project.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Wrong password | Show "Incorrect password" error |
| Corrupt file | Show "Invalid backup file" error |
| Wrong file type | Show "Not a summsumm backup" error |
| Missing permissions | Show permission request dialog |
| Export to same filename | Overwrite silently (temp files) |
| Import with missing audio | Import metadata only, no error |

## Testing

- Unit tests for `BackupService` with mock repositories
- Widget tests for `BackupScreen` interactions
- Integration test: export → import roundtrip

## Future Considerations

- Version field enables future migrations (e.g., add new settings fields)
- Could add cloud backup (Google Drive / iCloud) as separate feature
- Could add scheduled automatic backups

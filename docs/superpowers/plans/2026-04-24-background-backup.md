# Background Backup with Direct Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable backup to run as a foreground service (survives app backgrounding) and add direct save to Downloads folder alongside existing share sheet option.

**Architecture:** Android foreground service with persistent notification keeps backup alive when user leaves app. Flutter MethodChannel controls service lifecycle. Backup UI offers two modes: "Share" (existing) or "Save to device" (new, saves to Downloads). Isolate-based computation already in place keeps UI responsive.

**Tech Stack:** Flutter, Kotlin (Android foreground service), MethodChannel, path_provider, share_plus (existing), notification permissions.

---

## File Structure

**New files:**
- `android/app/src/main/kotlin/app/summsumm/BackupForegroundService.kt` — Android foreground service for backup
- `lib/services/backup_destination.dart` — Abstraction for backup save destinations
- `test/services/backup_destination_test.dart` — Tests for destination handling

**Modified files:**
- `android/app/src/main/kotlin/app/summsumm/MainActivity.kt` — Add MethodChannel handlers for backup service
- `android/app/src/main/AndroidManifest.xml` — Declare backup foreground service
- `lib/screens/backup_screen.dart` — Add destination picker UI
- `lib/services/backup_service.dart` — Add save to file method
- `pubspec.yaml` — Add permission_handler (already present)
- `lib/l10n/app_en.arb` — Add new localization strings
- `lib/l10n/app_de.arb` — Add new localization strings

---

## Task 1: Create backup destination abstraction

**Files:**
- Create: `lib/services/backup_destination.dart`
- Test: `test/services/backup_destination_test.dart`

- [ ] **Step 1.1: Write failing test for BackupDestination**

Create `test/services/backup_destination_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/backup_destination.dart';

void main() {
  group('BackupDestination', () {
    test('getDownloadsPath returns valid path on Android', () async {
      final path = await BackupDestination.getDownloadsPath();
      expect(path, isNotNull);
      expect(path, contains('Download'));
    });

    test('generateFilename creates timestamped filename', () {
      final filename = BackupDestination.generateFilename();
      expect(filename, endsWith('.summsumm'));
      expect(filename, contains('_backup'));
    });
  });
}
```

- [ ] **Step 1.2: Run test to verify it fails**

Run: `flutter test test/services/backup_destination_test.dart`
Expected: FAIL with "BackupDestination not found"

- [ ] **Step 1.3: Implement BackupDestination**

Create `lib/services/backup_destination.dart`:

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class BackupDestination {
  static Future<String?> getDownloadsPath() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first.path;
      }
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return p.join(p.dirname(extDir.path), 'Download');
      }
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    return null;
  }

  static String generateFilename() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${dateStr}_${timeStr}_backup.summsumm';
  }

  static Future<File> getBackupFile([String? customName]) async {
    final downloadsPath = await getDownloadsPath();
    if (downloadsPath == null) {
      throw Exception('Could not access Downloads folder');
    }
    final filename = customName ?? generateFilename();
    final file = File(p.join(downloadsPath, filename));
    return file;
  }
}
```

- [ ] **Step 1.4: Run test to verify it passes**

Run: `flutter test test/services/backup_destination_test.dart`
Expected: PASS

- [ ] **Step 1.5: Commit**

```bash
git add lib/services/backup_destination.dart test/services/backup_destination_test.dart
git commit -m "feat: add BackupDestination for Downloads folder access"
```

---

## Task 2: Create Android foreground service

**Files:**
- Create: `android/app/src/main/kotlin/app/summsumm/BackupForegroundService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 2.1: Create BackupForegroundService**

Create `android/app/src/main/kotlin/app/summsumm/BackupForegroundService.kt`:

```kotlin
package app.summsumm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import android.content.pm.ServiceInfo

class BackupForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "BackupServiceChannel"
        const val NOTIFICATION_ID = 2
        const val ACTION_START = "app.summsumm.START_BACKUP"
        const val ACTION_STOP = "app.summsumm.STOP_BACKUP"
        
        fun start(context: Context) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private lateinit var notificationManager: NotificationManager

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Backup Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows backup progress"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Creating backup")
            .setContentText("Please wait...")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setProgress(100, 0, true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }
}
```

- [ ] **Step 2.2: Add service to AndroidManifest.xml**

Read `android/app/src/main/AndroidManifest.xml` and add the service declaration inside the `<application>` tag, after the existing `<service>` for RecordingService:

```xml
        <service
            android:name=".BackupForegroundService"
            android:exported="false"
            android:foregroundServiceType="dataSync" />
```

Also add the foreground service permission inside the `<manifest>` tag, after existing permissions:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```

- [ ] **Step 2.3: Commit**

```bash
git add android/app/src/main/kotlin/app/summsumm/BackupForegroundService.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat: add BackupForegroundService for background backup"
```

---

## Task 3: Add MethodChannel handlers in MainActivity

**Files:**
- Modify: `android/app/src/main/kotlin/app/summsumm/MainActivity.kt`

- [ ] **Step 3.1: Add backup service MethodChannel handlers**

Read `android/app/src/main/kotlin/app/summsumm/MainActivity.kt` and find the existing MethodChannel handler. Add the following cases to the `when (call.method)` block:

```kotlin
                "startBackupForeground" -> {
                    BackupForegroundService.start(this)
                    result.success(null)
                }
                "stopBackupForeground" -> {
                    BackupForegroundService.stop(this)
                    result.success(null)
                }
```

- [ ] **Step 3.2: Verify the file compiles**

Run: `cd android && ./gradlew assembleDebug --console=plain 2>&1 | head -50`
Expected: BUILD SUCCESSFUL (or at least no compilation errors)

- [ ] **Step 3.3: Commit**

```bash
git add android/app/src/main/kotlin/app/summsumm/MainActivity.kt
git commit -m "feat: add MethodChannel handlers for backup foreground service"
```

---

## Task 4: Add localization strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`

- [ ] **Step 4.1: Add English strings**

Add to `lib/l10n/app_en.arb` (before the closing brace):

```json
  "backupShare": "Share backup file",
  "backupSaveToDevice": "Save to device",
  "backupSavedToDownloads": "Backup saved to Downloads",
  "backupSaveFailed": "Failed to save backup",
  "backupModeLabel": "How would you like to export?",
  "backupModeShare": "Share",
  "backupModeSave": "Save to Downloads"
```

- [ ] **Step 4.2: Add German strings**

Add to `lib/l10n/app_de.arb` (before the closing brace):

```json
  "backupShare": "Backupdatei teilen",
  "backupSaveToDevice": "Auf Gerät speichern",
  "backupSavedToDownloads": "Backup in Downloads gespeichert",
  "backupSaveFailed": "Backup konnte nicht gespeichert werden",
  "backupModeLabel": "Wie möchtest du exportieren?",
  "backupModeShare": "Teilen",
  "backupModeSave": "In Downloads speichern"
```

- [ ] **Step 4.3: Regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Step 4.4: Commit**

```bash
git add lib/l10n/*.arb lib/l10n/app_localizations*.dart
git commit -m "feat: add localization strings for backup destination modes"
```

---

## Task 5: Add saveToFile method to BackupService

**Files:**
- Modify: `lib/services/backup_service.dart`

- [ ] **Step 5.1: Add saveToFile method to BackupService**

Read `lib/services/backup_service.dart` and add this method after the existing `export` method:

```dart
  /// Exports backup directly to a file path (e.g., Downloads folder).
  /// Returns the file that was written.
  Future<File> saveToFile({
    required String password,
    required bool includeSettings,
    required bool includeApiKeys,
    required bool includeMeetings,
    required bool includeAudio,
    required String outputPath,
  }) async {
    final settings = includeSettings ? _getSettings() : null;
    String? openrouterKey;
    String? openaiKey;

    if (includeApiKeys && includeSettings) {
      openrouterKey = await _secureStorage.getApiKey('openrouter');
      openaiKey = await _secureStorage.getApiKey('openai');
    }

    final allMeetings = await _meetingRepository.loadAll();
    final meetings = includeMeetings ? allMeetings : <Meeting>[];

    final filePath = await compute(_exportInIsolate, {
      'password': password,
      'settingsJson': settings?.toJson(),
      'openrouterKey': openrouterKey,
      'openaiKey': openaiKey,
      'meetingsJson': meetings.map((m) => m.toJson()).toList(),
      'includeAudio': includeAudio,
      'filename': p.basenameWithoutExtension(outputPath),
      'outputDir': p.dirname(outputPath),
    });

    return File(filePath);
  }
```

- [ ] **Step 5.2: Verify compilation**

Run: `flutter analyze lib/services/backup_service.dart`
Expected: No issues found

- [ ] **Step 5.3: Commit**

```bash
git add lib/services/backup_service.dart
git commit -m "feat: add saveToFile method to BackupService for direct file saving"
```

---

## Task 6: Update BackupScreen with destination picker

**Files:**
- Modify: `lib/screens/backup_screen.dart`

- [ ] **Step 6.1: Add destination mode enum and state**

Read `lib/screens/backup_screen.dart` and add after the existing imports:

```dart
enum _BackupMode { share, saveToDevice }
```

Add state variable in `_BackupScreenState` class (after existing state variables):

```dart
  _BackupMode _backupMode = _BackupMode.share;
```

- [ ] **Step 6.2: Add destination picker UI**

Find the "Export" button in the `build` method (the `FilledButton.icon` widget). Before the `const SizedBox(height: 16)` above the button, add:

```dart
                    const SizedBox(height: 16),
                    Text(
                      l10n.backupModeLabel,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_BackupMode>(
                      segments: [
                        ButtonSegment(
                          value: _BackupMode.share,
                          label: Text(l10n.backupModeShare),
                          icon: const Icon(Icons.share, size: 18),
                        ),
                        ButtonSegment(
                          value: _BackupMode.saveToDevice,
                          label: Text(l10n.backupModeSave),
                          icon: const Icon(Icons.save, size: 18),
                        ),
                      ],
                      selected: {_backupMode},
                      onSelectionChanged: (Set<_BackupMode> selection) {
                        setState(() => _backupMode = selection.first);
                      },
                    ),
```

- [ ] **Step 6.3: Update _export method to handle both modes**

Replace the entire `_export` method with:

```dart
  Future<void> _export() async {
    final password = await _showPasswordDialog(isExport: true);
    if (password == null || password.isEmpty) return;

    setState(() => _isExporting = true);

    const platform = MethodChannel('app.summsumm/intent');
    
    try {
      if (_backupMode == _BackupMode.saveToDevice) {
        platform.invokeMethod('startBackupForeground');
      }

      final service = ref.read(backupServiceProvider);

      if (_backupMode == _BackupMode.share) {
        final tempDir = await getTemporaryDirectory();
        final file = await service.export(
          password: password,
          includeSettings: _includeSettings,
          includeApiKeys: _includeApiKeys && _includeSettings,
          includeMeetings: _includeMeetings,
          includeAudio: _includeAudio && _includeMeetings,
          filename: _filenameCtrl.text,
          outputDir: tempDir.path,
        );

        if (mounted) {
          await Share.shareXFiles(
            [XFile(file.path)],
            subject: 'Summsumm Backup',
          );
        }
      } else {
        final backupFile = await BackupDestination.getBackupFile('$_filenameCtrl.text.summsumm');
        await service.saveToFile(
          password: password,
          includeSettings: _includeSettings,
          includeApiKeys: _includeApiKeys && _includeSettings,
          includeMeetings: _includeMeetings,
          includeAudio: _includeAudio && _includeMeetings,
          outputPath: backupFile.path,
        );

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.backupSavedToDownloads),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_backupMode == _BackupMode.share
                ? l10n.backupExportFailed(e.toString())
                : l10n.backupSaveFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (_backupMode == _BackupMode.saveToDevice) {
        platform.invokeMethod('stopBackupForeground');
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }
```

- [ ] **Step 6.4: Add missing imports**

Add at the top of `lib/screens/backup_screen.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:summsumm/services/backup_destination.dart';
```

- [ ] **Step 6.5: Verify compilation**

Run: `flutter analyze lib/screens/backup_screen.dart`
Expected: No issues found

- [ ] **Step 6.6: Commit**

```bash
git add lib/screens/backup_screen.dart
git commit -m "feat: add destination picker to BackupScreen (share vs save to device)"
```

---

## Task 7: Run verification

- [ ] **Step 7.1: Run all backup tests**

Run: `flutter test --timeout=120s test/services/backup_service_test.dart test/services/backup_integration_test.dart test/models/backup_data_test.dart test/services/backup_destination_test.dart`
Expected: All tests pass

- [ ] **Step 7.2: Run full test suite**

Run: `flutter test`
Expected: All tests pass (may have 1 pre-existing failure unrelated to this change)

- [ ] **Step 7.3: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors (warnings/info acceptable)

- [ ] **Step 7.4: Final commit**

```bash
git add -A
git commit -m "feat: complete background backup with direct save implementation"
```

---

## Spec Coverage Checklist

| Requirement | Task |
|---|---|
| Backup survives app backgrounding | Task 2 (foreground service) |
| Save directly to Downloads | Task 1, 5, 6 |
| Keep share sheet option | Task 6 (mode picker) |
| Notification while backup running | Task 2 (service notification) |
| UI to choose destination | Task 6 (segmented button) |

## Placeholder Scan

- No TBD/TODO/fill-in-details found
- All code blocks contain complete implementations
- All commands are specific and runnable

## Type Consistency Check

- `BackupDestination` methods used in Task 6 match Task 1 definitions
- `BackupService.saveToFile` matches usage in Task 6
- Localization keys match between arb files and Dart code

# Meeting Library Enhancements — Design Spec

**Date:** 2026-04-18  
**Status:** Approved

## Overview

Four enhancements to the meeting library: share sheet (audio/transcript/summary), rename from the list, slide-to-archive/delete swipe actions, and a browsable archived meetings section.

---

## 1. Data Model & Repository

### `Meeting` model
- Add `archived` bool field, default `false`.
- Update `copyWith`, `toJson`, `fromJson`. `fromJson` defaults `archived` to `false` so existing stored records are unaffected.

### `MeetingRepository`
- Add `archive(Meeting meeting)` method: calls `save(meeting.copyWith(archived: true))`.
- `loadAll()` unchanged — returns all meetings; filtering happens in the provider layer.

### Providers
- `meetingLibraryProvider` filters `archived == false` (active meetings).
- New `archivedMeetingsProvider` mirrors it, filtering `archived == true`.
- `MeetingNotifier` gains `archive()` method: sets `archived: true`, saves, then `ref.read(meetingLibraryProvider.notifier).refresh()`.
- `MeetingNotifier` gains `unarchive()` method: sets `archived: false`, saves, refreshes both providers.

---

## 2. Swipe Actions on List Tiles

### Package
Add `flutter_slidable` to `pubspec.yaml`.

### Active list tile (`_MeetingTile`)
Wrap in `Slidable` with two action panes:

**Drag right → left-side actions (constructive, teal/blue):**
- Share icon — opens `MeetingShareSheet` bottom sheet.
- Rename icon — opens rename dialog (same as detail screen).

**Drag left → right-side actions (destructive):**
- Archive icon (amber) — calls `notifier.archive()`, shows undo snackbar (4s timeout; tap undo calls `notifier.unarchive()`).
- Delete icon (red) — shows confirmation `AlertDialog` before calling `notifier.delete()`.

The trailing status button (`Transcribe` / `Summarize` / spinner / checkmark) remains always visible and is not part of the swipe.

---

## 3. Share Sheet

### Widget: `MeetingShareSheet`
A reusable widget shown via `showModalBottomSheet`. Receives a `Meeting`.

**Available options (hidden if not applicable):**
| Option | Condition | Share method |
|---|---|---|
| Share Audio | always | `ShareXFiles([XFile(meeting.audioPath)])` |
| Share Transcript | `meeting.transcript != null` | `Share.share(meeting.transcript!)` |
| Share Summary | `meeting.summary != null` | `Share.share(meeting.summary!)` |

Each option is a `ListTile` with an icon and label. Tapping an option shares then closes the sheet.

### Access points
- Active list tile: left swipe → share action.
- Detail screen (`MeetingDetailScreen`): share `IconButton` added to `AppBar.actions` (between edit and delete).
- Archived list tile: detail screen only (no swipe share needed in archive).

### Package
Add `share_plus` to `pubspec.yaml`.

---

## 4. Archived Meetings Section

### `ArchivedMeetingsScreen`
New screen. Accessed via archive icon button in `MeetingLibraryScreen` app bar (next to settings).

Displays meetings from `archivedMeetingsProvider`. Empty state: "No archived meetings."

**Swipe actions on archived tiles:**
- Drag right → Unarchive (blue) — calls `notifier.unarchive()`, snackbar confirmation.
- Drag left → Delete (red) — confirmation dialog.

Tapping a tile navigates to `MeetingDetailScreen` (rename/share/delete remain accessible there).

---

## 5. Detail Screen Updates

- Add share `IconButton` to `AppBar.actions` → opens `MeetingShareSheet`.
- Existing rename (edit icon) and delete icons remain.
- No archive action in detail screen — archive is a list-level gesture only.

---

## Error Handling

- If audio file is missing when sharing audio, show a `SnackBar` error instead of crashing.
- Archive/unarchive are fire-and-forget with undo; no error state needed.
- Delete failure shows a `SnackBar` error.

---

## Files Changed

| File | Change |
|---|---|
| `pubspec.yaml` | Add `flutter_slidable`, `share_plus` |
| `lib/models/meeting.dart` | Add `archived` field |
| `lib/services/meeting_repository.dart` | Add `archive()` method |
| `lib/providers/meeting_library_provider.dart` | Filter active only; add `archivedMeetingsProvider` |
| `lib/providers/meeting_provider.dart` | Add `archive()`, `unarchive()` methods |
| `lib/screens/meeting_library_screen.dart` | Slidable tiles, archive icon in app bar |
| `lib/screens/meeting_detail_screen.dart` | Add share icon |
| `lib/screens/archived_meetings_screen.dart` | New screen |
| `lib/widgets/meeting_share_sheet.dart` | New widget |

# summsumm Knowledge Hub — Design Specification

**Date**: 2026-04-22
**Status**: Draft — Awaiting Review

---

## 1. Vision

Transform summsumm from a summarization tool into a **personal knowledge hub** — the heart of anyone's knowledge. It tracks all meetings, retrieves information flawlessly, knows when/where/what was said, integrates all knowledge, tracks todos, and reads from the device calendar.

---

## 2. Priority Order

1. **Calendar Integration** (read-only from device calendar)
2. **Todo Extraction** (AI extracts action items from meetings)
3. **Semantic Search** (sqlite-vec for vector search across all content)
4. **Audio Playback with Transcript Sync**

---

## 3. Architecture Overview

### 3.1 Data Layer Migration

**Current**: JSON files (`meetings/*.json`) + `SharedPreferences`
**Target**: SQLite database with structured tables

**Rationale**: 
- JSON files don't scale for search, relationships, or complex queries
- SQLite enables structured storage, indexing, and sqlite-vec integration
- Migration is transparent to users (one-time data migration on app update)

**Tables**:

```sql
-- Core meetings table (replaces JSON files)
CREATE TABLE meetings (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL,  -- Unix timestamp
    duration_sec INTEGER,
    audio_path TEXT,
    transcript TEXT,
    summary TEXT,
    status TEXT NOT NULL,  -- recorded, transcribing, transcribed, summarizing, done, failed
    provider TEXT,
    archived INTEGER DEFAULT 0,
    type TEXT DEFAULT 'meeting',  -- meeting, document
    transcription_log TEXT,
    transcription_status TEXT,
    transcription_progress REAL,
    was_live_transcribed INTEGER DEFAULT 0,
    last_error TEXT,
    -- Metadata for search
    speaker_count INTEGER,
    word_count INTEGER
);

-- Speaker segments (extracted from diarization)
CREATE TABLE speaker_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id TEXT NOT NULL,
    speaker_label TEXT NOT NULL,
    start_time REAL NOT NULL,
    end_time REAL NOT NULL,
    text TEXT NOT NULL,
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
);

-- Meeting summaries (supports multiple styles)
CREATE TABLE meeting_summaries (
    id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL,
    style TEXT NOT NULL,
    language TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
);

-- Todos extracted from meetings
CREATE TABLE todos (
    id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL,
    content TEXT NOT NULL,
    completed INTEGER DEFAULT 0,
    due_date INTEGER,  -- Unix timestamp, optional
    created_at INTEGER NOT NULL,
    assigned_to TEXT,  -- Speaker label from diarization
    source_context TEXT,  -- Transcript snippet
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
);

-- Calendar events (read-only cache from device calendar)
CREATE TABLE calendar_events (
    id TEXT PRIMARY KEY,  -- Device calendar event ID
    title TEXT NOT NULL,
    description TEXT,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    location TEXT,
    calendar_id TEXT NOT NULL,
    calendar_name TEXT,
    last_synced INTEGER NOT NULL
);

-- Links between meetings and calendar events
CREATE TABLE meeting_calendar_links (
    meeting_id TEXT NOT NULL,
    calendar_event_id TEXT NOT NULL,
    confidence REAL,  -- AI confidence that this meeting belongs to this event
    PRIMARY KEY (meeting_id, calendar_event_id),
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
    FOREIGN KEY (calendar_event_id) REFERENCES calendar_events(id) ON DELETE CASCADE
);

-- Settings (replaces SharedPreferences for app settings)
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

### 3.2 sqlite-vec Integration (Phase 3)

**When**: After SQLite migration is complete and stable

**Setup**:
```sql
-- Load extension (done at app startup)
SELECT load_extension('sqlite-vec');

-- Create virtual table for embeddings
CREATE VIRTUAL TABLE content_embeddings USING vec0(
    content_id TEXT NOT NULL,           -- Foreign key to meetings.id or speaker_segments.id
    content_type TEXT NOT NULL,         -- 'meeting', 'segment', 'summary', 'document'
    embedding float[384]                -- 384-dim for all-MiniLM-L6-v2
);
```

**Embedding Generation**:
- **User-configurable**: Settings screen allows choosing between local (on-device) and cloud embedding generation
- **Local**: Use ONNX runtime with all-MiniLM-L6-v2 (~80MB model, no internet)
- **Cloud**: OpenAI `text-embedding-3-small` or OpenRouter equivalent (requires API key)
- **Hybrid**: Cloud when online, local fallback when offline

**Search Query**:
```sql
-- KNN search with metadata filtering
SELECT 
    e.content_id,
    e.content_type,
    distance
FROM content_embeddings e
WHERE e.embedding MATCH ?1  -- Query embedding
  AND e.content_type = ?2   -- Filter by type
ORDER BY distance
LIMIT 20;
```

### 3.3 Service Layer

```
┌─────────────────────────────────────────┐
│           UI Layer                      │
│  Library | Player | Todos | Search | Calendar│
├─────────────────────────────────────────┤
│         Providers (Riverpod)            │
│  MeetingLibrary | AudioPlayer | Todo | Search│
├─────────────────────────────────────────┤
│         Services                        │
│  ┌─────────────┐ ┌─────────────┐       │
│  │ CalendarService│ │ TodoExtraction │       │
│  │ (device_calendar)│ │ (AI prompt)    │       │
│  └─────────────┘ └─────────────┘       │
│  ┌─────────────┐ ┌─────────────┐       │
│  │ EmbeddingService│ │ AudioService   │       │
│  │ (local/cloud)  │ │ (playback/sync)│       │
│  └─────────────┘ └─────────────┘       │
├─────────────────────────────────────────┤
│         Storage                         │
│  ┌─────────────────────────────────┐   │
│  │ SQLite (sqlite3 + sqlite-vec)  │   │
│  │ - meetings, segments, summaries│   │
│  │ - todos, calendar_events       │   │
│  │ - content_embeddings (vec0)    │   │
│  └─────────────────────────────────┘   │
│  Audio Files (local filesystem)         │
└─────────────────────────────────────────┘
```

---

## 4. Phase 1: Calendar Integration (Read-Only)

### 4.1 Goal
Read calendar events from the device to:
- Suggest meeting titles when starting a recording
- Show "Upcoming Meetings" on the home screen
- Link recordings to calendar events (auto-detect based on time overlap)

### 4.2 Implementation

**Package**: `device_calendar: ^4.3.3`

**Permissions** (AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
```

**Flow**:
1. App startup: Request calendar permission
2. On grant: Sync last 30 days + next 7 days of events to `calendar_events` table
3. Background sync: Refresh every 15 minutes when app is active
4. UI: Show "Upcoming" section on library screen

**Auto-Linking**:
- When recording starts, check if current time overlaps with any calendar event (±15 min)
- If overlap found, suggest event title as meeting title
- Store link in `meeting_calendar_links` with confidence score

**Data Model**:
```dart
class CalendarEvent {
  final String id;           // Device calendar event ID
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String calendarId;
  final String? calendarName;
  final DateTime lastSynced;
}
```

### 4.3 UI Changes

**Meeting Library Screen**:
- Add "Upcoming" section at top (collapsible)
- Show next 3 calendar events with time
- Tap event → pre-fill recording title

**Recording Screen**:
- Show suggested title from calendar if overlap detected
- Allow user to accept or edit

---

## 5. Phase 2: Todo Extraction

### 5.1 Goal
AI automatically extracts action items from meeting transcripts and creates trackable todos.

### 5.2 Implementation

**Trigger**: After meeting summarization completes (status = 'done')

**AI Prompt**:
```
Extract all action items from this meeting transcript. For each action item, identify:
1. The task description (clear, actionable)
2. Who it's assigned to (if mentioned, use speaker labels)
3. Any deadline mentioned

Format as JSON:
[
  {
    "content": "Follow up with marketing team",
    "assigned_to": "Speaker 1",
    "due_date": "2026-04-25"
  }
]

If no action items, return empty array [].
```

**Flow**:
1. Meeting summary completes
2. Fire todo extraction prompt with transcript
3. Parse JSON response
4. Insert into `todos` table
5. Show notification: "X action items extracted"

**Data Model**:
```dart
class Todo {
  final String id;
  final String meetingId;
  final String content;
  final bool completed;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? assignedTo;
  final String? sourceContext;  // Transcript snippet
}
```

### 5.3 UI Changes

**New "Todos" Tab**:
- Global todo list (all meetings)
- Filter: All | Today | Overdue | Completed
- Sort: Due date | Created | Meeting

**Meeting Detail Screen**:
- Add "Todos" tab alongside Summary/Transcript/Chat
- Show extracted todos for this meeting
- Allow mark complete, edit, delete

**Todo Item UI**:
- Checkbox for completion
- Content text
- Due date badge (red if overdue)
- Assigned to chip (if available)
- Tap → navigate to meeting detail

---

## 6. Phase 3: Semantic Search (sqlite-vec)

### 6.1 Goal
Search across all meetings, transcripts, summaries, and documents using natural language.

### 6.2 Implementation

**Step 1: SQLite Migration** (prerequisite)
- Migrate all JSON data to SQLite tables
- Ensure `sqlite3` package is working

**Step 2: sqlite-vec Setup**
- Download pre-compiled sqlite-vec libraries for Android/iOS
- Bundle in app build
- Load extension at database open

**Step 3: Embedding Generation**
- When content is created (meeting summarized, document imported):
  1. Chunk content into segments (e.g., 512 tokens)
  2. Generate embedding via chosen provider (local/cloud)
  3. Insert into `content_embeddings` vec0 table

**Step 4: Search Interface**
- Global search bar (like Spotlight)
- Query → generate embedding → KNN search
- Results grouped by type with relevance score

**Search Results UI**:
```
┌─────────────────────────────┐
│ 🔍 Search your knowledge...  │
├─────────────────────────────┤
│ Meetings (3)                │
│ ├─ "Q2 Planning" (92%)      │
│ ├─ "Sprint Review" (87%)    │
│ └─ "Client Call" (81%)      │
│                             │
│ Documents (2)               │
│ ├─ "Project Proposal.pdf"   │
│ └─ "Meeting Notes.md"       │
│                             │
│ Todos (1)                   │
│ └─ "Follow up with design"  │
└─────────────────────────────┘
```

### 6.3 Embedding Configuration

**Settings Screen Addition**:
```
Embedding Provider:
○ Local (on-device, 80MB model, works offline)
○ Cloud (OpenAI/OpenRouter, requires API key, higher quality)
○ Auto (cloud when online, local when offline)
```

**Local Model**: all-MiniLM-L6-v2 (384-dim, ~80MB)
**Cloud Model**: text-embedding-3-small (1536-dim) or OpenRouter equivalent

---

## 7. Phase 4: Audio Playback with Transcript Sync

### 7.1 Goal
Play meeting audio with synchronized transcript highlighting and speaker labels.

### 7.2 Implementation

**Audio Player Service**:
- Use `audioplayers` or `just_audio` package
- Load audio file from `meeting.audioPath`
- Expose play/pause/seek controls

**Transcript Sync**:
- Parse speaker segments with timestamps
- Current playback time → find active segment
- Highlight current segment in transcript
- Auto-scroll transcript to keep current segment visible

**Tap-to-Seek**:
- Tap any transcript segment → seek audio to that timestamp
- Visual indicator on tapped segment

**Speaker Colors**:
- Assign consistent colors to speakers per meeting
- Show color indicator next to speaker label

### 7.3 UI Changes

**Meeting Detail Screen — Transcript Tab**:
- Split view: Audio player (top) + Transcript (bottom)
- Audio player: Play/pause, seek bar, time display
- Transcript: Scrollable list of segments
- Active segment: Highlighted background
- Inactive segments: Normal styling

---

## 8. Migration Strategy

### 8.1 JSON → SQLite Migration

**One-time migration on app update**:
1. Check if `meetings/` directory exists with JSON files
2. Read all JSON files
3. Insert into SQLite tables
4. Mark migration complete in `app_settings`
5. Keep JSON files as backup (don't delete)

**Code**:
```dart
class DatabaseMigration {
  static Future<void> migrateFromJson() async {
    final db = await DatabaseService.open();
    final migrated = await db.getSetting('migration_v2_complete');
    if (migrated == 'true') return;
    
    final repository = MeetingRepository();
    final meetings = await repository.loadAll();
    
    for (final meeting in meetings) {
      await db.insertMeeting(meeting);
      // Also migrate speaker segments, summaries
    }
    
    await db.setSetting('migration_v2_complete', 'true');
  }
}
```

### 8.2 Settings Migration

- Read existing `SharedPreferences` settings
- Insert into `app_settings` table
- Keep SharedPreferences for backward compatibility during transition

---

## 9. Technical Decisions

### 9.1 Why sqlite-vec over mobile_rag_engine?

| Feature | sqlite-vec | mobile_rag_engine |
|---------|-----------|-------------------|
| Size | ~100KB | Unknown |
| Dependencies | None | Unknown |
| Maturity | 7.5k GitHub stars, active | Newer, less proven |
| Flutter Support | Manual integration | Unknown |
| Metadata Support | Yes (partition keys, aux columns) | Unknown |
| BM25 Hybrid | Manual (separate FTS) | Built-in |

**Decision**: sqlite-vec for vector search + SQLite FTS5 for keyword search = hybrid search

### 9.2 Why device_calendar over CalDAV?

| Feature | device_calendar | CalDAV |
|---------|----------------|--------|
| Setup | Zero config | Server URL, credentials |
| Coverage | Any synced calendar | CalDAV servers only |
| Permissions | READ_CALENDAR | Internet + auth |
| Task Support | No (events only) | VTODO (but Google doesn't support it) |

**Decision**: device_calendar for read-only event access. Todo sync to calendar can be added later via Google Tasks API if needed.

### 9.3 Database Package Choice

| Package | Pros | Cons |
|---------|------|------|
| **sqlite3** | FFI-based, fast, supports extensions | Manual setup |
| sqflite | Popular, easy to use | Slower, no extension support |
| drift | Type-safe, code generation | More complex, build step |

**Decision**: `sqlite3` for direct SQLite access + extension loading capability

---

## 10. Open Questions

1. **Embedding Dimensions**: Should we standardize on 384-dim (all-MiniLM) or support variable dimensions (384 for local, 1536 for cloud)?
2. **Search UI**: Should search be a separate screen or integrated into the library screen?
3. **Todo Notifications**: Should overdue todos trigger push notifications?
4. **Calendar Sync Frequency**: Real-time (expensive) or periodic (every 15 min)?
5. **Audio Format**: Current recordings are in what format? Do we need transcoding for playback?

---

## 11. Success Criteria

- [ ] Calendar events appear in app within 15 minutes of device calendar update
- [ ] Recording start suggests correct meeting title 80% of the time
- [ ] AI extracts actionable todos from 90% of meetings
- [ ] Semantic search returns relevant results in <500ms
- [ ] Audio playback syncs with transcript within ±1 second accuracy
- [ ] All existing functionality (summarization, transcription, chat) continues to work

---

## 12. Appendix: File Structure

```
lib/
├── database/
│   ├── database_service.dart      # SQLite connection, migrations
│   ├── meeting_dao.dart           # Meeting CRUD
│   ├── todo_dao.dart              # Todo CRUD
│   ├── calendar_dao.dart          # Calendar event CRUD
│   └── embedding_dao.dart         # sqlite-vec operations
├── services/
│   ├── calendar_service.dart      # device_calendar wrapper
│   ├── todo_extraction_service.dart # AI todo extraction
│   ├── embedding_service.dart     # Local/cloud embedding generation
│   └── audio_player_service.dart  # Audio playback
├── providers/
│   ├── calendar_provider.dart
│   ├── todo_provider.dart
│   ├── search_provider.dart
│   └── audio_player_provider.dart
└── screens/
    ├── todos_screen.dart
    ├── search_screen.dart
    └── widgets/
        ├── audio_player.dart
        ├── transcript_view.dart
        └── todo_list.dart
```

---

**Next Step**: Review this spec and provide feedback. Once approved, we'll create an implementation plan using the `writing-plans` skill.

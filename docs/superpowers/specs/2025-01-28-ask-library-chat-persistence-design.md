# Ask Library Chat Persistence Design

**Date**: 2025-01-28
**Status**: Approved

## Overview

Persist Ask Library chat sessions so users can return to previous conversations. Add a hamburger menu drawer to the `AskLibraryScreen` for browsing, loading, renaming, and deleting saved chats.

## Goals

- Auto-save every Ask Library chat session after each assistant response
- Allow users to browse previous chats via a hamburger menu drawer
- Support renaming and deleting saved chats
- Follow existing codebase patterns (file-based JSON, Riverpod, `MeetingRepository`)

## Non-Goals

- Search/filter within chat history (future enhancement)
- Archive functionality (not needed for chat sessions)
- Export/share individual chat sessions
- Chat folders or categorization

## Data Model

### `ChatSession`

New model in `lib/models/chat_session.dart`:

```dart
class ChatSession {
  final String id;                 // UUID
  final String title;              // Auto-generated from first user message
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool isArchived;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isArchived = false,
  });

  // copyWith, toJson, fromJson following Meeting pattern
}
```

### `ChatMessage` Extension

The existing `ChatMessage` model (`lib/models/chat_message.dart`) gains a `metadata` field to store citation data:

```dart
class ChatMessage {
  final String role;
  final String content;
  final Map<String, dynamic>? metadata;  // Stores citations, etc.

  // existing methods + metadata in toJson/fromJson
}
```

Citation data from `AskLibraryMessage` is serialized into `metadata` when saving, and deserialized back when loading.

## Repository Layer

### `ChatRepository`

New service in `lib/services/chat_repository.dart`:

```dart
class ChatRepository {
  static const _chatsDirName = 'ask_library_chats';

  Future<Directory> _chatsDir() async;
  Future<List<ChatSession>> loadAll() async;
  Future<ChatSession?> loadById(String id) async;
  Future<void> save(ChatSession session) async;
  Future<void> delete(String id) async;
}
```

Implementation follows `MeetingRepository` exactly:
- Files stored in `app_documents/ask_library_chats/`
- Each session as `{id}.json`
- Atomic writes via temp-file rename
- Graceful handling of corrupt files (skip with debug log)
- Results sorted by `updatedAt` descending

## State Management

### New Providers

1. **`chatRepositoryProvider`** - `Provider<ChatRepository>`
   - Single instance, injected where needed

2. **`askLibraryChatHistoryProvider`** - `StateNotifierProvider<AskLibraryChatHistoryNotifier, List<ChatSession>>`
   - Manages the list of all saved chat sessions
   - Loads on initialization
   - Refreshes after save/delete/rename

3. **`askLibrarySessionProvider`** - `StateNotifierProvider.family<AskLibrarySessionNotifier, AskLibrarySessionState, String?>`
   - Manages an individual chat session
   - `null` ID = new unsaved session
   - Integrates with existing streaming logic

### Refactored Providers

- **`askLibraryChatProvider`** - Refactored to use `askLibrarySessionProvider` internally
  - Maintains backward-compatible API
  - Triggers auto-save after assistant response completes

### Auto-Save Lifecycle

```
User sends message
    → Assistant streams response
    → onDone (successful response only):
        1. Generate title from first user message of session (if new session)
           - Format: "Q: {first 50 chars of first user message}"
        2. Call ChatRepository.save(session)
        3. Update askLibraryChatHistoryProvider
    → onError: Do NOT auto-save. Error state remains in-memory only.
```

## UI Changes

### AskLibraryScreen

#### AppBar Changes

- **Leading**: Hamburger icon (`Icons.menu`) opens drawer
- **Actions**: Keep existing "New chat" button (plus icon)
- **Title**: Remains "Ask Library" or shows active chat title

#### Drawer (`ChatHistoryDrawer`)

New widget in `lib/widgets/chat_history_drawer.dart`:

```
┌─────────────────────────┐
│  ≡ Ask Library          │
├─────────────────────────┤
│  + New Chat             │
├─────────────────────────┤
│  📝 Q: What did we...   │  ← Chat title
│  Jan 28, 2025          │  ← Date
│  ─────────────────────  │
│  📝 Meeting notes review│
│  Jan 27, 2025          │
│  ...                   │
└─────────────────────────┘
```

**Drawer item interactions**:
- **Primary action**: Tap item → loads chat, closes drawer
- **Secondary actions**: Long-press item OR swipe left (Slidable) → reveals Rename/Delete actions
- Both long-press and Slidable swipe are supported for discoverability

#### Chat View Changes

When a saved chat is loaded:
- Messages populate from `ChatSession.messages`
- Streaming state is reset (no partial responses)
- New messages append to the loaded session
- Auto-save updates the same file

When "New chat" is tapped:
- Current session auto-saved (if has messages and last response was successful)
- Fresh empty session created
- Title clears

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Save failure | Debug log + subtle SnackBar "Failed to save chat" |
| Load failure (corrupt file) | Skip file, log warning, continue loading others |
| Delete failure | SnackBar with retry option |
| Rename failure | Revert UI, show error SnackBar |
| Drawer load failure | Show error state in drawer with retry button |

## Testing Strategy

- Unit tests for `ChatRepository` (save/load/delete)
- Unit tests for `ChatSession` serialization
- Widget test for drawer open/close
- Widget test for loading a saved chat
- Widget test for rename/delete actions

## Files to Create

- `lib/models/chat_session.dart`
- `lib/services/chat_repository.dart`
- `lib/providers/chat_repository_provider.dart`
- `lib/providers/ask_library_chat_history_provider.dart`
- `lib/providers/ask_library_session_provider.dart`
- `lib/widgets/chat_history_drawer.dart`

## Files to Modify

- `lib/models/chat_message.dart` - Add metadata field
- `lib/providers/ask_library_chat_provider.dart` - Integrate with session provider, trigger auto-save
- `lib/screens/ask_library_screen.dart` - Add drawer, hamburger menu, integrate new providers
- `lib/widgets/chat_history_drawer.dart` - New widget for the drawer UI

## Open Questions

None. All clarifying questions resolved during design phase.

## Dependencies

No new dependencies required. Uses existing:
- `path_provider`
- `path`
- `uuid`
- `flutter_riverpod`

## Performance Considerations

- Chat history list loads all session metadata (title, date) from file system on init
- For expected volumes (dozens of chats), this is acceptable
- If volumes grow to 100+, consider adding a `metadata.json` index file (future)
- Message content is only loaded when a specific chat is opened

## Migration / Backward Compatibility

- Existing unsaved chats are not retroactively saved
- Users start with empty history; new chats auto-save going forward
- No migration needed for existing `AskLibraryMessage` data (in-memory only)

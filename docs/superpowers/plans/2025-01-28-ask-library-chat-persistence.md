# Ask Library Chat Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Ask Library chat sessions with a drawer UI for browsing, loading, renaming, and deleting previous conversations.

**Architecture:** File-based JSON storage mirroring MeetingRepository pattern, Riverpod state management with separate providers for history list and active session, Drawer widget for chat browsing.

**Tech Stack:** Flutter, Riverpod, file-based JSON storage

---

## File Structure

**New files:**
- `lib/models/chat_session.dart` - Chat session data model
- `lib/services/chat_repository.dart` - File-based chat persistence
- `lib/providers/chat_repository_provider.dart` - Repository dependency injection
- `lib/providers/ask_library_chat_history_provider.dart` - Chat history list state
- `lib/providers/ask_library_session_provider.dart` - Active chat session state
- `lib/widgets/chat_history_drawer.dart` - Drawer UI for chat browsing
- `test/services/chat_repository_test.dart` - Repository unit tests
- `test/models/chat_session_test.dart` - Model serialization tests

**Modified files:**
- `lib/models/chat_message.dart` - Add metadata field
- `lib/providers/ask_library_chat_provider.dart` - Integrate with session provider, auto-save
- `lib/screens/ask_library_screen.dart` - Add drawer, hamburger menu

---

### Task 1: Extend ChatMessage with metadata field

**Files:**
- Modify: `lib/models/chat_message.dart`
- Test: `test/models/chat_message_test.dart`

- [ ] **Step 1: Write failing test for metadata serialization**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_message.dart';

void main() {
  test('ChatMessage with metadata serializes to JSON', () {
    const message = ChatMessage(
      role: 'assistant',
      content: 'Hello',
      metadata: {'citations': [{'title': 'Doc 1'}]},
    );
    final json = message.toApiMap();
    expect(json['metadata'], isNotNull);
    expect(json['metadata']['citations'][0]['title'], 'Doc 1');
  });
}
```

Run: `flutter test test/models/chat_message_test.dart`
Expected: FAIL - `metadata` field doesn't exist

- [ ] **Step 2: Add metadata field to ChatMessage**

```dart
class ChatMessage {
  final String role;
  final String content;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.role,
    required this.content,
    this.metadata,
  });

  Map<String, dynamic> toApiMap() => {
    'role': role,
    'content': content,
    if (metadata != null) 'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.role == role &&
        other.content == content &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(role, content, metadata);
}
```

Run: `flutter test test/models/chat_message_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/models/chat_message.dart test/models/chat_message_test.dart
git commit -m "feat(chat): add metadata field to ChatMessage for citations"
```

---

### Task 2: Create ChatSession model

**Files:**
- Create: `lib/models/chat_session.dart`
- Test: `test/models/chat_session_test.dart`

- [ ] **Step 1: Write failing test for ChatSession serialization**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_session.dart';
import 'package:summsumm/models/chat_message.dart';

void main() {
  test('ChatSession serializes and deserializes', () {
    final session = ChatSession(
      id: 'test-id',
      title: 'Q: Hello world',
      createdAt: DateTime(2025, 1, 28),
      updatedAt: DateTime(2025, 1, 28, 12),
      messages: [
        const ChatMessage(role: 'user', content: 'Hello'),
        const ChatMessage(role: 'assistant', content: 'Hi there'),
      ],
    );
    
    final json = session.toJson();
    final restored = ChatSession.fromJson(json);
    
    expect(restored.id, 'test-id');
    expect(restored.title, 'Q: Hello world');
    expect(restored.messages.length, 2);
    expect(restored.messages[0].content, 'Hello');
  });
}
```

Run: `flutter test test/models/chat_session_test.dart`
Expected: FAIL - ChatSession doesn't exist

- [ ] **Step 2: Implement ChatSession model**

```dart
import 'dart:convert';
import 'chat_message.dart';

class ChatSession {
  final String id;
  final String title;
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

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    bool? isArchived,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'messages': messages.map((m) => m.toApiMap()).toList(),
      'isArchived': isArchived,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      messages: messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatSession.fromJsonString(String s) =>
      ChatSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
```

Run: `flutter test test/models/chat_session_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/models/chat_session.dart test/models/chat_session_test.dart
git commit -m "feat(chat): add ChatSession model with serialization"
```

---

### Task 3: Create ChatRepository

**Files:**
- Create: `lib/services/chat_repository.dart`
- Test: `test/services/chat_repository_test.dart`

- [ ] **Step 1: Write failing test for ChatRepository**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/chat_session.dart';
import 'package:summsumm/models/chat_message.dart';
import 'package:summsumm/services/chat_repository.dart';

void main() {
  late ChatRepository repository;

  setUp(() {
    repository = ChatRepository();
  });

  test('save and load chat session', () async {
    final session = ChatSession(
      id: 'test-1',
      title: 'Test Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [const ChatMessage(role: 'user', content: 'Hello')],
    );

    await repository.save(session);
    final loaded = await repository.loadById('test-1');
    
    expect(loaded, isNotNull);
    expect(loaded!.title, 'Test Chat');
  });
}
```

Run: `flutter test test/services/chat_repository_test.dart`
Expected: FAIL - ChatRepository doesn't exist

- [ ] **Step 2: Implement ChatRepository**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/chat_session.dart';

class ChatRepository {
  static const _chatsDirName = 'ask_library_chats';

  Future<Directory> _chatsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final chatsDir = Directory(path.join(docsDir.path, _chatsDirName));
    await chatsDir.create(recursive: true);
    return chatsDir;
  }

  Future<List<ChatSession>> loadAll() async {
    try {
      final dir = await _chatsDir();
      final jsonFiles = dir.listSync().where((e) => e.path.endsWith('.json'));
      final sessions = <ChatSession>[];

      for (final file in jsonFiles) {
        try {
          final json = jsonDecode(
            File(file.path).readAsStringSync(),
          ) as Map<String, dynamic>;
          sessions.add(ChatSession.fromJson(json));
        } catch (e, st) {
          debugPrint('Error loading chat from ${file.path}: $e\n$st');
        }
      }

      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (e, st) {
      debugPrint('Error in loadAll(): $e\n$st');
      return [];
    }
  }

  Future<ChatSession?> loadById(String id) async {
    try {
      final dir = await _chatsDir();
      final file = File(path.join(dir.path, '$id.json'));
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ChatSession.fromJson(json);
    } catch (e, st) {
      debugPrint('Error loading chat $id: $e\n$st');
      return null;
    }
  }

  Future<void> save(ChatSession session) async {
    final dir = await _chatsDir();
    final jsonFile = File(path.join(dir.path, '${session.id}.json'));
    final tempFile = File('${jsonFile.path}.tmp');
    tempFile.writeAsStringSync(jsonEncode(session.toJson()));
    await tempFile.rename(jsonFile.path);
  }

  Future<void> delete(String id) async {
    final dir = await _chatsDir();
    final file = File(path.join(dir.path, '$id.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

Run: `flutter test test/services/chat_repository_test.dart`
Expected: PASS

- [ ] **Step 3: Add test for delete and loadAll ordering**

```dart
  test('delete removes chat session', () async {
    final session = ChatSession(
      id: 'delete-test',
      title: 'To Delete',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );

    await repository.save(session);
    await repository.delete('delete-test');
    final loaded = await repository.loadById('delete-test');
    expect(loaded, isNull);
  });

  test('loadAll sorts by updatedAt descending', () async {
    final session1 = ChatSession(
      id: 'old',
      title: 'Old',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [],
    );
    final session2 = ChatSession(
      id: 'new',
      title: 'New',
      createdAt: DateTime(2025, 1, 2),
      updatedAt: DateTime(2025, 1, 2),
      messages: [],
    );

    await repository.save(session1);
    await repository.save(session2);
    final all = await repository.loadAll();
    
    expect(all[0].id, 'new');
    expect(all[1].id, 'old');
  });
```

Run: `flutter test test/services/chat_repository_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/services/chat_repository.dart test/services/chat_repository_test.dart
git commit -m "feat(chat): add ChatRepository with file-based persistence"
```

---

### Task 4: Create providers for chat history and active session

**Files:**
- Create: `lib/providers/chat_repository_provider.dart`
- Create: `lib/providers/ask_library_chat_history_provider.dart`
- Create: `lib/providers/ask_library_session_provider.dart`

- [ ] **Step 1: Create chat_repository_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});
```

- [ ] **Step 2: Create ask_library_chat_history_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import 'chat_repository_provider.dart';

class AskLibraryChatHistoryNotifier extends StateNotifier<List<ChatSession>> {
  final Ref _ref;

  AskLibraryChatHistoryNotifier(this._ref) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final repository = _ref.read(chatRepositoryProvider);
    final sessions = await repository.loadAll();
    state = sessions;
  }

  Future<void> refresh() async {
    await _loadHistory();
  }

  Future<void> deleteSession(String id) async {
    final repository = _ref.read(chatRepositoryProvider);
    await repository.delete(id);
    await refresh();
  }

  Future<void> renameSession(String id, String newTitle) async {
    final repository = _ref.read(chatRepositoryProvider);
    final session = await repository.loadById(id);
    if (session == null) return;

    final updated = session.copyWith(title: newTitle);
    await repository.save(updated);
    await refresh();
  }
}

final askLibraryChatHistoryProvider =
    StateNotifierProvider<AskLibraryChatHistoryNotifier, List<ChatSession>>(
  (ref) => AskLibraryChatHistoryNotifier(ref),
);
```

- [ ] **Step 3: Create ask_library_session_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import 'chat_repository_provider.dart';

class AskLibrarySessionState {
  final String? id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  AskLibrarySessionState({
    this.id,
    this.title = '',
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  AskLibrarySessionState copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AskLibrarySessionState(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AskLibrarySessionNotifier extends StateNotifier<AskLibrarySessionState> {
  final Ref _ref;

  AskLibrarySessionNotifier(this._ref)
      : super(AskLibrarySessionState(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

  void loadSession(ChatSession session) {
    state = AskLibrarySessionState(
      id: session.id,
      title: session.title,
      messages: session.messages,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      updatedAt: DateTime.now(),
    );
  }

  void newSession() {
    state = AskLibrarySessionState(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveCurrentSession() async {
    if (state.messages.isEmpty) return;

    final title = state.title.isNotEmpty
        ? state.title
        : _generateTitle(state.messages);

    final session = ChatSession(
      id: state.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: state.createdAt,
      updatedAt: DateTime.now(),
      messages: state.messages,
    );

    final repository = _ref.read(chatRepositoryProvider);
    await repository.save(session);

    // Update state with assigned ID if it was new
    if (state.id == null) {
      state = state.copyWith(id: session.id);
    }
  }

  String _generateTitle(List<ChatMessage> messages) {
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => const ChatMessage(role: 'user', content: 'New Chat'),
    );
    final content = firstUserMessage.content;
    if (content.length <= 50) return 'Q: $content';
    return 'Q: ${content.substring(0, 50)}...';
  }
}

final askLibrarySessionProvider =
    StateNotifierProvider<AskLibrarySessionNotifier, AskLibrarySessionState>(
  (ref) => AskLibrarySessionNotifier(ref),
);
```

- [ ] **Step 4: Commit**

```bash
git add lib/providers/chat_repository_provider.dart \
        lib/providers/ask_library_chat_history_provider.dart \
        lib/providers/ask_library_session_provider.dart
git commit -m "feat(chat): add providers for chat history and active session"
```

---

### Task 5: Create ChatHistoryDrawer widget

**Files:**
- Create: `lib/widgets/chat_history_drawer.dart`

- [ ] **Step 1: Implement ChatHistoryDrawer**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/chat_session.dart';
import '../providers/ask_library_chat_history_provider.dart';
import '../providers/ask_library_session_provider.dart';

class ChatHistoryDrawer extends ConsumerWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(askLibraryChatHistoryProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            const Divider(),
            Expanded(
              child: sessions.isEmpty
                  ? const Center(child: Text('No saved chats'))
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _ChatListItem(session: sessions[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chat History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(askLibrarySessionProvider.notifier).newSession();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('New Chat'),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final ChatSession session;

  const _ChatListItem({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context, ref),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            icon: Icons.edit,
            label: 'Rename',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, ref),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        title: Text(session.title),
        onTap: () {
          ref.read(askLibrarySessionProvider.notifier).loadSession(session);
          Navigator.pop(context);
        },
        onLongPress: () => _showActionsBottomSheet(context, ref),
      ),
    );
  }

  void _showActionsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(askLibraryChatHistoryProvider.notifier)
                  .renameSession(session.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(askLibraryChatHistoryProvider.notifier)
                  .deleteSession(session.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/chat_history_drawer.dart
git commit -m "feat(chat): add ChatHistoryDrawer widget with rename/delete"
```

---

### Task 6: Modify AskLibraryScreen to integrate drawer and session management

**Files:**
- Modify: `lib/screens/ask_library_screen.dart`

- [ ] **Step 1: Update imports and add drawer to scaffold**

Add these imports at the top:
```dart
import '../providers/ask_library_session_provider.dart';
import '../widgets/chat_history_drawer.dart';
```

Modify the Scaffold to include drawer:
```dart
return Scaffold(
  appBar: AppBar(
    leading: Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    ),
    title: Text(AppLocalizations.of(context)!.askLibraryTitle),
    actions: [
      if (chat.messages.isNotEmpty)
        IconButton(
          tooltip: 'New chat',
          onPressed: () {
            // Save current session if it has messages
            ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
            ref.read(askLibrarySessionProvider.notifier).newSession();
            _newChat();
          },
          icon: const Icon(Icons.add_comment_outlined),
        ),
    ],
  ),
  drawer: const ChatHistoryDrawer(),
  body: // existing body
```

- [ ] **Step 2: Integrate session provider with chat UI**

In `_ChatView`, display messages from the session provider instead of directly from `chat.messages`. The session provider becomes the source of truth for the active conversation.

Watch `askLibrarySessionProvider` to rebuild when session changes:
```dart
final session = ref.watch(askLibrarySessionProvider);
```

Use `session.messages` instead of `chat.messages` in the ListView.builder.

- [ ] **Step 3: Update send message to save to session**

After sending a message and receiving the assistant response, save the session:
```dart
// After successful assistant response
await ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
ref.read(askLibraryChatHistoryProvider.notifier).refresh();
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/ask_library_screen.dart
git commit -m "feat(chat): integrate drawer and session management into AskLibraryScreen"
```

---

### Task 7: Modify AskLibraryChatProvider to integrate with session provider

**Files:**
- Modify: `lib/providers/ask_library_chat_provider.dart`

- [ ] **Step 1: Add imports for session provider**

```dart
import 'ask_library_session_provider.dart';
```

- [ ] **Step 2: Update sendMessage to save messages to session**

After each successful message exchange, add messages to the session:
```dart
// In sendMessage, after assistant response completes:
ref.read(askLibrarySessionProvider.notifier).addMessage(userMessage);
ref.read(askLibrarySessionProvider.notifier).addMessage(assistantMessage);
await ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
ref.read(askLibraryChatHistoryProvider.notifier).refresh();
```

- [ ] **Step 3: Update newChat to save before clearing**

```dart
void newChat() {
  // Save current session before clearing
  _ref.read(askLibrarySessionProvider.notifier).saveCurrentSession();
  _ref.read(askLibraryChatHistoryProvider.notifier).refresh();
  
  _streamSub?.cancel();
  _streamSub = null;
  state = const AskLibraryChatState();
  _ref.read(askLibrarySessionProvider.notifier).newSession();
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/providers/ask_library_chat_provider.dart
git commit -m "feat(chat): integrate AskLibraryChatProvider with session persistence"
```

---

### Task 8: Run full test suite and lint

- [ ] **Step 1: Run all tests**

```bash
flutter test
```

Expected: All tests pass (existing + new)

- [ ] **Step 2: Run linter**

```bash
flutter analyze
```

Expected: No errors, no warnings

- [ ] **Step 3: Commit**

```bash
git commit --allow-empty -m "test: all tests passing for chat persistence feature"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|-----------------|------|
| Auto-save after successful assistant response | Task 6, 7 |
| Chat title from first user message | Task 4 (AskLibrarySessionNotifier._generateTitle) |
| Drawer with hamburger menu | Task 6 |
| Drawer shows chat titles only (no date) | Task 5 |
| Tap chat to load | Task 5 |
| Long-press for rename/delete | Task 5 |
| Swipe left for rename/delete (Slidable) | Task 5 |
| New chat button in drawer | Task 5 |
| New chat saves current session first | Task 6, 7 |
| File-based JSON storage | Task 3 |
| Follow MeetingRepository pattern | Task 3 |
| Error handling (skip corrupt files) | Task 3 |
| No new dependencies | All tasks |

## Open Questions

None. All requirements from the approved spec are covered.

## Execution Options

**Plan complete and saved to `docs/superpowers/plans/2025-01-28-ask-library-chat-persistence.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

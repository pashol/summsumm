# Meeting Detail Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-scroll meeting detail view with Summary / Transcript / Chat tabs.

**Architecture:** `MeetingDetailScreen` gains a `TabController` (3 tabs). A new ephemeral `meetingChatProvider` (family by meetingId) holds chat state using `AiService.streamCompletion()` with the meeting transcript+summary as context. No model changes, no code generation.

**Tech Stack:** Flutter, Riverpod (`StateNotifierProvider.family`), `AiService.streamCompletion()`, `ChatMessage`, `flutter_markdown`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/providers/meeting_chat_provider.dart` | **Create** | `MeetingChatState`, `MeetingChatNotifier`, `meetingChatProvider` |
| `lib/screens/meeting_detail_screen.dart` | **Modify** | Convert body to TabBar + TabBarView; move action buttons into tabs |

---

### Task 1: Create `MeetingChatProvider`

**Files:**
- Create: `lib/providers/meeting_chat_provider.dart`
- Create: `test/providers/meeting_chat_provider_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/providers/meeting_chat_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/providers/meeting_chat_provider.dart';

void main() {
  test('initial state has empty messages and is not streaming', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(meetingChatProvider('test-id'));
    expect(state.messages, isEmpty);
    expect(state.isStreaming, false);
    expect(state.error, isNull);
  });

  test('different meetingIds get independent state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final a = container.read(meetingChatProvider('a'));
    final b = container.read(meetingChatProvider('b'));
    expect(identical(a, b), false);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/providers/meeting_chat_provider_test.dart
```
Expected: compilation error (file doesn't exist yet).

- [ ] **Step 3: Create `lib/providers/meeting_chat_provider.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/meeting_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

class MeetingChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? error;

  const MeetingChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  MeetingChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) =>
      MeetingChatState(
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        error: clearError ? null : (error ?? this.error),
      );
}

class MeetingChatNotifier extends StateNotifier<MeetingChatState> {
  final Ref _ref;
  StreamSubscription<String>? _streamSub;
  bool _mounted = true;

  MeetingChatNotifier(this._ref) : super(const MeetingChatState());

  Future<void> sendMessage(
    String question, {
    required String transcript,
    String? summary,
  }) async {
    if (state.isStreaming || question.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: question.trim());
    final assistantMsg = ChatMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
      clearError: true,
    );

    final settings = _ref.read(settingsProvider);
    final apiKey =
        await _ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';

    final systemPrompt =
        'You are a helpful assistant. The user recorded a meeting.\n'
        'Transcript:\n$transcript\n'
        '${summary != null ? '\nSummary:\n$summary\n' : ''}'
        '\nAnswer questions about this meeting concisely.';

    final history = state.messages
        .take(state.messages.length - 1) // exclude the empty assistant msg
        .map((m) => m.toApiMap())
        .toList();

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
    ];

    try {
      final stream = _ref.read(aiServiceProvider).streamCompletion(
            apiKey: apiKey,
            model: settings.activeModel,
            messages: apiMessages,
            provider: settings.provider,
          );

      String accumulated = '';
      _streamSub = stream.listen(
        (delta) {
          if (!_mounted) return;
          accumulated += delta;
          final updated = List<ChatMessage>.from(state.messages);
          updated[updated.length - 1] =
              ChatMessage(role: 'assistant', content: accumulated);
          state = state.copyWith(messages: updated);
        },
        onError: (Object e) {
          if (!_mounted) return;
          final msgs = List<ChatMessage>.from(state.messages)
            ..removeLast();
          state = state.copyWith(
            messages: msgs,
            isStreaming: false,
            error: e is AiException ? e.message : e.toString(),
          );
        },
        onDone: () {
          if (!_mounted) return;
          state = state.copyWith(isStreaming: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final msgs = List<ChatMessage>.from(state.messages)..removeLast();
      state = state.copyWith(
        messages: msgs,
        isStreaming: false,
        error: e is AiException ? e.message : e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _streamSub?.cancel();
    super.dispose();
  }
}

final meetingChatProvider =
    StateNotifierProvider.family<MeetingChatNotifier, MeetingChatState, String>(
  (ref, meetingId) => MeetingChatNotifier(ref),
);
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/providers/meeting_chat_provider_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 5: Verify no analysis errors**

```bash
flutter analyze lib/providers/meeting_chat_provider.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/meeting_chat_provider.dart test/providers/meeting_chat_provider_test.dart
git commit -m "feat: add MeetingChatProvider for ephemeral meeting chat state"
```

---

### Task 2: Refactor `MeetingDetailScreen` — tab scaffold

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

Convert the screen's state class to use a `TabController` and restructure `build()` into the tab layout. Replace the `SingleChildScrollView` body with a `Column` containing the metadata strip, `TabBar`, and `Expanded(TabBarView)`.

- [ ] **Step 1: Add `TickerProviderStateMixin` and `TabController`**

Replace the class declaration and `initState`/`dispose`:

```dart
class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen>
    with TickerProviderStateMixin {
  bool _diarize = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meetingLibraryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Replace `build()` body with tab layout**

Replace the `body:` of the `Scaffold` in `build()`:

```dart
body: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: _buildMetadata(meeting),
    ),
    TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Summary'),
        Tab(text: 'Transcript'),
        Tab(text: 'Chat'),
      ],
    ),
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(meeting, provider),
          _buildTranscriptTab(meeting, provider),
          _buildChatTab(meeting),
        ],
      ),
    ),
  ],
),
```

- [ ] **Step 3: Run analyze to check for issues**

```bash
flutter analyze lib/screens/meeting_detail_screen.dart
```
Fix any errors before continuing.

- [ ] **Step 4: Commit scaffold**

```bash
git add lib/screens/meeting_detail_screen.dart
git commit -m "refactor: convert MeetingDetailScreen body to TabBar/TabBarView scaffold"
```

---

### Task 3: Implement Summary and Transcript tabs

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

Replace `_buildActions()` with two focused tab methods. The existing `_buildActions()` logic splits between the two tabs.

- [ ] **Step 1: Add `_buildSummaryTab()`**

Add this method to `_MeetingDetailScreenState`:

```dart
Widget _buildSummaryTab(Meeting meeting, MeetingNotifier provider) {
  Widget content;
  switch (meeting.status) {
    case MeetingStatus.recorded:
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No transcript yet.\nGo to the Transcript tab to transcribe.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    case MeetingStatus.transcribing:
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Transcribing…'),
          ],
        ),
      );
    case MeetingStatus.transcribed:
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: provider.summarize,
            child: const Text('Summarize'),
          ),
        ),
      );
    case MeetingStatus.summarizing:
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Summarizing…'),
          ],
        ),
      );
    case MeetingStatus.done:
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(data: meeting.summary ?? ''),
      );
    case MeetingStatus.failed:
      content = const SizedBox.shrink();
  }
  return content;
}
```

- [ ] **Step 2: Add `_buildTranscriptTab()`**

```dart
Widget _buildTranscriptTab(Meeting meeting, MeetingNotifier provider) {
  switch (meeting.status) {
    case MeetingStatus.recorded:
      final settings = ref.watch(settingsProvider);
      final isOpenRouter = settings.provider == 'openrouter';
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: isOpenRouter ? '' : 'Diarization requires OpenRouter',
              child: Row(
                children: [
                  Switch(
                    value: _diarize,
                    onChanged: isOpenRouter
                        ? (v) => setState(() => _diarize = v)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Diarize speakers',
                    style: TextStyle(
                      color:
                          isOpenRouter ? null : Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => provider.transcribe(diarize: _diarize),
              child: const Text('Transcribe'),
            ),
          ],
        ),
      );
    case MeetingStatus.transcribing:
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Transcribing…'),
          ],
        ),
      );
    case MeetingStatus.transcribed:
    case MeetingStatus.summarizing:
    case MeetingStatus.done:
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(meeting.transcript ?? ''),
      );
    case MeetingStatus.failed:
      if (meeting.type == MeetingType.document) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: provider.retry,
            child: const Text('Retry'),
          ),
        ),
      );
  }
}
```

- [ ] **Step 3: Remove `_buildActions()` and its call site**

Delete the `_buildActions()` method entirely. It is no longer called — the logic now lives in the two tab methods above.

- [ ] **Step 4: Run analyze**

```bash
flutter analyze lib/screens/meeting_detail_screen.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart
git commit -m "feat: implement Summary and Transcript tabs in MeetingDetailScreen"
```

---

### Task 4: Implement Chat tab

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

Add `_buildChatTab()` with message list + input row. Wire up `meetingChatProvider`.

- [ ] **Step 1: Add import for `meeting_chat_provider`**

Add to the imports at the top of `meeting_detail_screen.dart`:

```dart
import 'package:summsumm/providers/meeting_chat_provider.dart';
```

- [ ] **Step 2: Add `_chatInputController` to state class**

In `_MeetingDetailScreenState`, add a field and initialize/dispose it:

```dart
final TextEditingController _chatInputController = TextEditingController();
final ScrollController _chatScrollController = ScrollController();

// in dispose():
@override
void dispose() {
  _tabController.dispose();
  _chatInputController.dispose();
  _chatScrollController.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Add `_buildChatTab()`**

```dart
Widget _buildChatTab(Meeting meeting) {
  if (meeting.transcript == null) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Transcribe the meeting first to start chatting.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  final chatState = ref.watch(meetingChatProvider(meeting.id));
  final chatNotifier = ref.read(meetingChatProvider(meeting.id).notifier);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  return Column(
    children: [
      Expanded(
        child: ListView.builder(
          controller: _chatScrollController,
          padding: const EdgeInsets.all(16),
          itemCount: chatState.messages.length,
          itemBuilder: (context, index) {
            final msg = chatState.messages[index];
            final isUser = msg.role == 'user';
            return Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(msg.content),
              ),
            );
          },
        ),
      ),
      if (chatState.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            chatState.error!,
            style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatInputController,
                decoration: const InputDecoration(
                  hintText: 'Ask about this meeting…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: chatState.isStreaming
                    ? null
                    : (_) => _sendChatMessage(meeting, chatNotifier),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: chatState.isStreaming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: chatState.isStreaming
                  ? null
                  : () => _sendChatMessage(meeting, chatNotifier),
            ),
          ],
        ),
      ),
    ],
  );
}

void _sendChatMessage(Meeting meeting, MeetingChatNotifier notifier) {
  final text = _chatInputController.text.trim();
  if (text.isEmpty) return;
  _chatInputController.clear();
  notifier.sendMessage(
    text,
    transcript: meeting.transcript!,
    summary: meeting.summary,
  );
}
```

- [ ] **Step 4: Run analyze**

```bash
flutter analyze lib/screens/meeting_detail_screen.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart
git commit -m "feat: implement Chat tab in MeetingDetailScreen"
```

---

### Task 5: Manual smoke test on device

- [ ] **Step 1: Run on device**

```bash
flutter run
```

- [ ] **Step 2: Navigate to a meeting in the library**

Verify:
- Three tabs appear: Summary, Transcript, Chat
- Metadata (date/duration/error) is visible above the tabs
- Swiping between tabs works

- [ ] **Step 3: Test each tab state**

For a **recorded** meeting (no transcript):
- Summary tab → "No transcript yet" placeholder
- Transcript tab → diarize toggle + Transcribe button
- Chat tab → "Transcribe first" placeholder

For a **transcribed** meeting:
- Summary tab → Summarize button
- Transcript tab → transcript text
- Chat tab → chat UI active; send a message and verify AI responds

For a **done** meeting:
- Summary tab → markdown summary
- Transcript tab → transcript text
- Chat tab → send a follow-up; verify response streams in correctly

- [ ] **Step 4: Final analyze + test**

```bash
flutter analyze
flutter test
```
Expected: no issues, all tests pass.

- [ ] **Step 5: Final commit if any fixups needed**

```bash
git add -A
git commit -m "fix: meeting detail tabs smoke test fixups"
```

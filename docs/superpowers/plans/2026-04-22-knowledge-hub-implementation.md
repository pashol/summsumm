# summsumm Knowledge Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform summsumm from a summarization tool into a personal knowledge hub with calendar integration, todo extraction, semantic search, and audio playback sync — while keeping JSON files for storage until Phase 3.

**Architecture:** Keep existing JSON file storage for meetings. Add new JSON files for calendar events and todos. Use `device_calendar` for read-only calendar access. Use AI prompts for todo extraction. Defer SQLite/sqlite-vec migration to Phase 3 (semantic search).

**Tech Stack:** Flutter, Riverpod, JSON file storage, device_calendar, AI streaming (existing)

---

## Phase 1: Calendar Integration (Read-Only)

### Task 1: Add device_calendar dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add dependency**

Add to `pubspec.yaml` dependencies section:
```yaml
device_calendar: ^4.3.3
```

- [ ] **Step 2: Add Android permission**

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
```

- [ ] **Step 3: Get packages**

Run: `flutter pub get`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml android/app/src/main/AndroidManifest.xml
git commit -m "deps: add device_calendar for calendar integration"
```

---

### Task 2: Create CalendarEvent model

**Files:**
- Create: `lib/models/calendar_event.dart`

- [ ] **Step 1: Write model**

```dart
import 'package:flutter/foundation.dart';

@immutable
class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String calendarId;
  final String? calendarName;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.calendarId,
    this.calendarName,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? calendarId,
    String? calendarName,
  }) =>
      CalendarEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        calendarId: calendarId ?? this.calendarId,
        calendarName: calendarName ?? this.calendarName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'location': location,
        'calendarId': calendarId,
        'calendarName': calendarName,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        startTime: DateTime.parse(json['startTime'] as String).toUtc(),
        endTime: DateTime.parse(json['endTime'] as String).toUtc(),
        location: json['location'] as String?,
        calendarId: json['calendarId'] as String,
        calendarName: json['calendarName'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/calendar_event.dart
git commit -m "feat: add CalendarEvent model"
```

---

### Task 3: Create CalendarRepository

**Files:**
- Create: `lib/services/calendar_repository.dart`

- [ ] **Step 1: Write repository**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/calendar_event.dart';

class CalendarRepository {
  static const _calendarFileName = 'calendar_events.json';

  Future<File> _calendarFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(path.join(docsDir.path, _calendarFileName));
  }

  Future<List<CalendarEvent>> loadAll() async {
    try {
      final file = await _calendarFile();
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      return json
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('Error loading calendar events: $e\n$st');
      return [];
    }
  }

  Future<void> saveAll(List<CalendarEvent> events) async {
    final file = await _calendarFile();
    final json = events.map((e) => e.toJson()).toList();
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(json));
    await tempFile.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _calendarFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/calendar_repository.dart
git commit -m "feat: add CalendarRepository for JSON persistence"
```

---

### Task 4: Create CalendarService

**Files:**
- Create: `lib/services/calendar_service.dart`

- [ ] **Step 1: Write service**

```dart
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:summsumm/models/calendar_event.dart';
import 'package:summsumm/services/calendar_repository.dart';

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  final CalendarRepository _repository = CalendarRepository();

  Future<bool> requestPermission() async {
    final result = await _plugin.requestPermissions();
    return result.data ?? false;
  }

  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.data ?? false;
  }

  Future<List<CalendarEvent>> syncCalendarEvents() async {
    if (!await hasPermission()) {
      debugPrint('Calendar permission not granted');
      return [];
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];

    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    final endDate = now.add(const Duration(days: 7));

    final allEvents = <CalendarEvent>[];

    for (final calendar in calendars) {
      if (calendar.id == null) continue;

      final eventsResult = await _plugin.retrieveEvents(
        calendar.id!,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );

      final events = eventsResult.data ?? [];
      for (final event in events) {
        if (event.eventId == null || event.title == null) continue;
        if (event.start == null) continue;

        allEvents.add(CalendarEvent(
          id: event.eventId!,
          title: event.title!,
          description: event.description,
          startTime: event.start!,
          endTime: event.end ?? event.start!.add(const Duration(hours: 1)),
          location: event.location,
          calendarId: calendar.id!,
          calendarName: calendar.name,
        ));
      }
    }

    // Sort by start time
    allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Save to JSON
    await _repository.saveAll(allEvents);

    return allEvents;
  }

  Future<List<CalendarEvent>> loadCachedEvents() async {
    return _repository.loadAll();
  }

  /// Find overlapping calendar event for a given time range
  CalendarEvent? findOverlappingEvent(
    List<CalendarEvent> events,
    DateTime start,
    DateTime end, {
    Duration tolerance = const Duration(minutes: 15),
  }) {
    final adjustedStart = start.subtract(tolerance);
    final adjustedEnd = end.add(tolerance);

    for (final event in events) {
      if (event.endTime.isBefore(adjustedStart)) continue;
      if (event.startTime.isAfter(adjustedEnd)) continue;
      return event;
    }
    return null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/calendar_service.dart
git commit -m "feat: add CalendarService with device_calendar integration"
```

---

### Task 5: Create CalendarProvider

**Files:**
- Create: `lib/providers/calendar_provider.dart`

- [ ] **Step 1: Write provider**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/calendar_event.dart';
import 'package:summsumm/services/calendar_service.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) => CalendarService());

final calendarEventsProvider =
    AsyncNotifierProvider<CalendarEventsNotifier, List<CalendarEvent>>(
  CalendarEventsNotifier.new,
);

class CalendarEventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
  @override
  Future<List<CalendarEvent>> build() async {
    final service = ref.read(calendarServiceProvider);
    
    // First load cached events for immediate display
    final cached = await service.loadCachedEvents();
    
    // Then sync in background
    _syncInBackground(service);
    
    return cached;
  }

  Future<void> _syncInBackground(CalendarService service) async {
    try {
      final events = await service.syncCalendarEvents();
      state = AsyncValue.data(events);
    } catch (e, st) {
      debugPrint('Calendar sync failed: $e\n$st');
      // Keep cached data on error
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(calendarServiceProvider);
      return service.syncCalendarEvents();
    });
  }

  Future<bool> requestPermission() async {
    final service = ref.read(calendarServiceProvider);
    return service.requestPermission();
  }

  Future<bool> hasPermission() async {
    final service = ref.read(calendarServiceProvider);
    return service.hasPermission();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/calendar_provider.dart
git commit -m "feat: add CalendarProvider with background sync"
```

---

### Task 6: Add calendar permission to onboarding

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Add calendar permission page**

Add a new page to the onboarding wizard (after the existing pages) that requests calendar permission. Insert before the final "Get Started" page:

```dart
// In onboarding_screen.dart, add to the PageView children list:

_buildCalendarPermissionPage(),

// Add method:
Widget _buildCalendarPermissionPage() {
  return Consumer(
    builder: (context, ref, child) {
      final l10n = AppLocalizations.of(context)!;
      return _OnboardingPage(
        icon: Icons.calendar_today_outlined,
        title: l10n.onboardingCalendarTitle,
        description: l10n.onboardingCalendarDescription,
        child: FilledButton.icon(
          onPressed: () async {
            final notifier = ref.read(calendarEventsProvider.notifier);
            final granted = await notifier.requestPermission();
            if (granted) {
              await notifier.refresh();
            }
            _nextPage();
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(l10n.onboardingCalendarButton),
        ),
      );
    },
  );
}
```

- [ ] **Step 2: Add localization strings**

Add to `lib/l10n/app_en.arb`:
```json
{
  "onboardingCalendarTitle": "Connect Your Calendar",
  "onboardingCalendarDescription": "Allow access to suggest meeting titles and show upcoming events.",
  "onboardingCalendarButton": "Grant Calendar Access"
}
```

Add to `lib/l10n/app_de.arb`:
```json
{
  "onboardingCalendarTitle": "Kalender verbinden",
  "onboardingCalendarDescription": "Erlaube den Zugriff, um Meeting-Titel vorzuschlagen und anstehende Termine anzuzeigen.",
  "onboardingCalendarButton": "Kalenderzugriff erlauben"
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding_screen.dart lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: add calendar permission to onboarding"
```

---

### Task 7: Show upcoming events on library screen

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`

- [ ] **Step 1: Add upcoming events section**

Modify `_buildList` to show upcoming events at the top:

```dart
Widget _buildList(List<Meeting> meetings, AppLocalizations l10n, WidgetRef ref) {
  final calendarAsync = ref.watch(calendarEventsProvider);
  
  return Column(
    children: [
      // Upcoming events section
      calendarAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (events) {
          final upcoming = events.where((e) => e.startTime.isAfter(DateTime.now())).take(3).toList();
          if (upcoming.isEmpty) return const SizedBox.shrink();
          
          return _UpcomingEventsSection(events: upcoming);
        },
      ),
      // Existing meeting list
      Expanded(
        child: meetings.isEmpty
            ? Center(child: Text(l10n.libraryNoItems))
            : SlidableAutoCloseBehavior(
                child: ListView.builder(
                  itemCount: meetings.length,
                  itemBuilder: (ctx, i) => _MeetingTile(meeting: meetings[i]),
                ),
              ),
      ),
    ],
  );
}
```

- [ ] **Step 2: Add _UpcomingEventsSection widget**

Add at the bottom of the file:

```dart
class _UpcomingEventsSection extends StatelessWidget {
  final List<CalendarEvent> events;

  const _UpcomingEventsSection({required this.events});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.libraryUpcomingEvents,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...events.map((event) => _EventTile(event: event)),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatEventTime(event.startTime, event.endTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventTime(DateTime start, DateTime end) {
    final now = DateTime.now();
    final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
    final isTomorrow = start.year == now.year && start.month == now.month && start.day == now.day + 1;
    
    String day;
    if (isToday) {
      day = 'Today';
    } else if (isTomorrow) {
      day = 'Tomorrow';
    } else {
      day = '${start.month}/${start.day}';
    }
    
    final startTime = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endTime = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    
    return '$day, $startTime - $endTime';
  }
}
```

- [ ] **Step 3: Add localization strings**

Add to `lib/l10n/app_en.arb`:
```json
{
  "libraryUpcomingEvents": "Upcoming"
}
```

Add to `lib/l10n/app_de.arb`:
```json
{
  "libraryUpcomingEvents": "Anstehend"
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/meeting_library_screen.dart lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: show upcoming calendar events on library screen"
```

---

### Task 8: Suggest meeting title from calendar on recording start

**Files:**
- Modify: `lib/screens/recording_screen.dart`

- [ ] **Step 1: Add calendar suggestion logic**

In `_startRecording`, before creating the meeting, check for overlapping calendar events:

```dart
Future<void> _startRecording() async {
  final status = await Permission.microphone.request();
  if (!status.isGranted) {
    // ... existing permission handling
    return;
  }

  // Check for calendar event overlap
  String title = _title;
  final calendarService = ref.read(calendarServiceProvider);
  if (await calendarService.hasPermission()) {
    final events = await calendarService.loadCachedEvents();
    final now = DateTime.now();
    final overlapping = calendarService.findOverlappingEvent(
      events,
      now,
      now.add(const Duration(hours: 1)),
    );
    if (overlapping != null) {
      title = overlapping.title;
    }
  }

  // ... rest of existing method, use 'title' instead of '_title'
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/recording_screen.dart
git commit -m "feat: suggest meeting title from calendar event on recording start"
```

---

## Phase 2: Todo Extraction

### Task 9: Create Todo model

**Files:**
- Create: `lib/models/todo.dart`

- [ ] **Step 1: Write model**

```dart
import 'package:flutter/foundation.dart';

@immutable
class Todo {
  final String id;
  final String meetingId;
  final String content;
  final bool completed;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? assignedTo;
  final String? sourceContext;

  const Todo({
    required this.id,
    required this.meetingId,
    required this.content,
    this.completed = false,
    this.dueDate,
    required this.createdAt,
    this.assignedTo,
    this.sourceContext,
  });

  Todo copyWith({
    String? id,
    String? meetingId,
    String? content,
    bool? completed,
    DateTime? dueDate,
    DateTime? createdAt,
    String? assignedTo,
    String? sourceContext,
  }) =>
      Todo(
        id: id ?? this.id,
        meetingId: meetingId ?? this.meetingId,
        content: content ?? this.content,
        completed: completed ?? this.completed,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt ?? this.createdAt,
        assignedTo: assignedTo ?? this.assignedTo,
        sourceContext: sourceContext ?? this.sourceContext,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'meetingId': meetingId,
        'content': content,
        'completed': completed,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'assignedTo': assignedTo,
        'sourceContext': sourceContext,
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as String,
        meetingId: json['meetingId'] as String,
        content: json['content'] as String,
        completed: json['completed'] as bool? ?? false,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String).toUtc()
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        assignedTo: json['assignedTo'] as String?,
        sourceContext: json['sourceContext'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/todo.dart
git commit -m "feat: add Todo model"
```

---

### Task 10: Create TodoRepository

**Files:**
- Create: `lib/services/todo_repository.dart`

- [ ] **Step 1: Write repository**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/todo.dart';

class TodoRepository {
  static const _todosFileName = 'todos.json';

  Future<File> _todosFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(path.join(docsDir.path, _todosFileName));
  }

  Future<List<Todo>> loadAll() async {
    try {
      final file = await _todosFile();
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      return json
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('Error loading todos: $e\n$st');
      return [];
    }
  }

  Future<List<Todo>> loadForMeeting(String meetingId) async {
    final all = await loadAll();
    return all.where((t) => t.meetingId == meetingId).toList();
  }

  Future<void> save(Todo todo) async {
    final all = await loadAll();
    final index = all.indexWhere((t) => t.id == todo.id);
    if (index >= 0) {
      all[index] = todo;
    } else {
      all.add(todo);
    }
    await _saveAll(all);
  }

  Future<void> saveAll(List<Todo> todos) async {
    final all = await loadAll();
    for (final todo in todos) {
      final index = all.indexWhere((t) => t.id == todo.id);
      if (index >= 0) {
        all[index] = todo;
      } else {
        all.add(todo);
      }
    }
    await _saveAll(all);
  }

  Future<void> delete(String todoId) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == todoId);
    await _saveAll(all);
  }

  Future<void> _saveAll(List<Todo> todos) async {
    final file = await _todosFile();
    final json = todos.map((t) => t.toJson()).toList();
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(json));
    await tempFile.rename(file.path);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/todo_repository.dart
git commit -m "feat: add TodoRepository for JSON persistence"
```

---

### Task 11: Create TodoExtractionService

**Files:**
- Create: `lib/services/todo_extraction_service.dart`

- [ ] **Step 1: Write service**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/todo.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/services/todo_repository.dart';
import 'package:uuid/uuid.dart';

class TodoExtractionService {
  final AiService _aiService;
  final TodoRepository _repository;

  TodoExtractionService({
    AiService? aiService,
    TodoRepository? repository,
  })  : _aiService = aiService ?? AiService(),
        _repository = repository ?? TodoRepository();

  static const _extractionPrompt = '''
Extract all action items from this meeting transcript. For each action item, identify:
1. The task description (clear, actionable)
2. Who it's assigned to (if mentioned, use speaker labels like "Speaker 1", "Speaker 2")
3. Any deadline mentioned (in ISO 8601 date format if possible)

Format your response as a JSON array:
[
  {
    "content": "Follow up with marketing team about campaign",
    "assigned_to": "Speaker 1",
    "due_date": "2026-04-25"
  }
]

If there are no action items, return an empty array: []

Transcript:
'';

  Future<List<Todo>> extractTodos(Meeting meeting, {
    required String apiKey,
    required String model,
    required String provider,
  }) async {
    if (meeting.transcript == null || meeting.transcript!.isEmpty) {
      debugPrint('No transcript available for todo extraction');
      return [];
    }

    try {
      final fullPrompt = '$_extractionPrompt\n${meeting.transcript}';
      
      final stream = _aiService.streamCompletion(
        apiKey: apiKey,
        model: model,
        messages: [
          {'role': 'user', 'content': fullPrompt},
        ],
        provider: provider,
      );

      String response = '';
      await for (final chunk in stream) {
        response += chunk;
      }

      // Extract JSON from response (handle markdown code blocks)
      final jsonStr = _extractJson(response);
      final List<dynamic> jsonList = jsonDecode(jsonStr);

      final todos = <Todo>[];
      for (final item in jsonList) {
        final map = item as Map<String, dynamic>;
        DateTime? dueDate;
        if (map['due_date'] != null) {
          try {
            dueDate = DateTime.parse(map['due_date'] as String);
          } catch (_) {
            // Invalid date format, skip
          }
        }

        todos.add(Todo(
          id: const Uuid().v4(),
          meetingId: meeting.id,
          content: map['content'] as String,
          assignedTo: map['assigned_to'] as String?,
          dueDate: dueDate,
          createdAt: DateTime.now(),
          sourceContext: _extractContext(meeting.transcript!, map['content'] as String),
        ));
      }

      // Save extracted todos
      await _repository.saveAll(todos);

      return todos;
    } catch (e, st) {
      debugPrint('Todo extraction failed: $e\n$st');
      return [];
    }
  }

  String _extractJson(String response) {
    // Try to extract JSON from markdown code block
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(response);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!.trim();
    }
    
    // Try to find JSON array directly
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
    if (arrayMatch != null) {
      return arrayMatch.group(0)!;
    }
    
    return '[]';
  }

  String _extractContext(String transcript, String todoContent) {
    // Find the sentence containing the todo content
    final sentences = transcript.split(RegExp(r'[.!?]+'));
    for (final sentence in sentences) {
      if (sentence.toLowerCase().contains(todoContent.toLowerCase().substring(0, todoContent.length ~/ 2))) {
        return sentence.trim();
      }
    }
    return '';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/todo_extraction_service.dart
git commit -m "feat: add TodoExtractionService with AI prompt"
```

---

### Task 12: Integrate todo extraction after summarization

**Files:**
- Modify: `lib/providers/meeting_provider.dart`

- [ ] **Step 1: Add todo extraction trigger**

After the summarization completes successfully in `MeetingNotifier.summarize()`, add:

```dart
// After: state = state.copyWith(status: MeetingStatus.done, clearLastError: true);
// await repository.save(state);
// ref.read(meetingLibraryProvider.notifier).refresh();

// Add todo extraction
await _extractTodos(meeting);
```

Add method:
```dart
Future<void> _extractTodos(Meeting meeting) async {
  try {
    final settings = ref.read(settingsProvider);
    final apiKey = await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
    
    if (apiKey.isEmpty) return;
    
    final service = TodoExtractionService();
    final todos = await service.extractTodos(
      meeting,
      apiKey: apiKey,
      model: settings.activeModel,
      provider: settings.provider,
    );
    
    if (todos.isNotEmpty && mounted) {
      // Show notification
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.todosExtracted(todos.length)),
          action: SnackBarAction(
            label: l10n.viewButton,
            onPressed: () {
              // Navigate to todos tab
            },
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Todo extraction error: $e');
  }
}
```

- [ ] **Step 2: Add imports**

Add to imports:
```dart
import 'package:summsumm/services/todo_extraction_service.dart';
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/meeting_provider.dart
git commit -m "feat: trigger todo extraction after meeting summarization"
```

---

### Task 13: Create TodoProvider

**Files:**
- Create: `lib/providers/todo_provider.dart`

- [ ] **Step 1: Write provider**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/todo.dart';
import 'package:summsumm/services/todo_repository.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) => TodoRepository());

final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);

class TodosNotifier extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() async {
    final repository = ref.read(todoRepositoryProvider);
    return repository.loadAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(todoRepositoryProvider);
      return repository.loadAll();
    });
  }

  Future<void> toggleComplete(String todoId) async {
    final repository = ref.read(todoRepositoryProvider);
    final todos = await repository.loadAll();
    final todo = todos.firstWhere((t) => t.id == todoId);
    final updated = todo.copyWith(completed: !todo.completed);
    await repository.save(updated);
    await refresh();
  }

  Future<void> deleteTodo(String todoId) async {
    final repository = ref.read(todoRepositoryProvider);
    await repository.delete(todoId);
    await refresh();
  }
}

final meetingTodosProvider = FutureProvider.family<List<Todo>, String>(
  (ref, meetingId) async {
    final repository = ref.read(todoRepositoryProvider);
    return repository.loadForMeeting(meetingId);
  },
);
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/todo_provider.dart
git commit -m "feat: add TodoProvider with CRUD operations"
```

---

### Task 14: Add Todos tab to meeting detail

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Add todos tab**

Change `TabController(length: 3, ...)` to `TabController(length: 4, ...)`

Add tab:
```dart
Tab(text: l10n.meetingDetailTabTodos),
```

Add tab view:
```dart
_buildTodosTab(meeting, l10n),
```

Add method:
```dart
Widget _buildTodosTab(Meeting meeting, AppLocalizations l10n) {
  final todosAsync = ref.watch(meetingTodosProvider(meeting.id));
  
  return todosAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('Error: $e')),
    data: (todos) {
      if (todos.isEmpty) {
        return Center(
          child: Text(
            l10n.meetingDetailNoTodos,
            textAlign: TextAlign.center,
          ),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return _TodoTile(todo: todo, meetingId: meeting.id);
        },
      );
    },
  );
}
```

- [ ] **Step 2: Add _TodoTile widget**

```dart
class _TodoTile extends ConsumerWidget {
  final Todo todo;
  final String meetingId;

  const _TodoTile({required this.todo, required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: todo.completed,
          onChanged: (_) => ref.read(todosProvider.notifier).toggleComplete(todo.id),
        ),
        title: Text(
          todo.content,
          style: TextStyle(
            decoration: todo.completed ? TextDecoration.lineThrough : null,
            color: todo.completed ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        subtitle: todo.assignedTo != null
            ? Text('Assigned to: ${todo.assignedTo}')
            : null,
        trailing: todo.dueDate != null
            ? Chip(
                label: Text(
                  '${todo.dueDate!.month}/${todo.dueDate!.day}',
                  style: TextStyle(
                    color: _isOverdue(todo.dueDate!) ? cs.error : cs.onSurface,
                  ),
                ),
                backgroundColor: _isOverdue(todo.dueDate!)
                    ? cs.errorContainer
                    : cs.surfaceContainerHighest,
              )
            : null,
      ),
    );
  }

  bool _isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }
}
```

- [ ] **Step 3: Add localization strings**

Add to `lib/l10n/app_en.arb`:
```json
{
  "meetingDetailTabTodos": "Todos",
  "meetingDetailNoTodos": "No action items extracted from this meeting.",
  "todosExtracted": "{count} action items extracted",
  "viewButton": "View"
}
```

Add to `lib/l10n/app_de.arb`:
```json
{
  "meetingDetailTabTodos": "Aufgaben",
  "meetingDetailNoTodos": "Keine Aufgaben aus diesem Meeting extrahiert.",
  "todosExtracted": "{count} Aufgaben extrahiert",
  "viewButton": "Ansehen"
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: add Todos tab to meeting detail screen"
```

---

### Task 15: Create global Todos screen

**Files:**
- Create: `lib/screens/todos_screen.dart`

- [ ] **Step 1: Write screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/todo.dart';
import 'package:summsumm/providers/todo_provider.dart';

class TodosScreen extends ConsumerWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final todosAsync = ref.watch(todosProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todosTitle),
      ),
      body: todosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (todos) => _TodosList(todos: todos),
      ),
    );
  }
}

class _TodosList extends StatefulWidget {
  final List<Todo> todos;

  const _TodosList({required this.todos});

  @override
  State<_TodosList> createState() => _TodosListState();
}

class _TodosListState extends State<_TodosList> {
  TodoFilter _filter = TodoFilter.all;

  List<Todo> get _filteredTodos {
    switch (_filter) {
      case TodoFilter.all:
        return widget.todos;
      case TodoFilter.active:
        return widget.todos.where((t) => !t.completed).toList();
      case TodoFilter.completed:
        return widget.todos.where((t) => t.completed).toList();
      case TodoFilter.overdue:
        return widget.todos.where((t) => 
          !t.completed && t.dueDate != null && t.dueDate!.isBefore(DateTime.now())
        ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<TodoFilter>(
            segments: [
              ButtonSegment(
                value: TodoFilter.all,
                label: Text(l10n.todosFilterAll),
              ),
              ButtonSegment(
                value: TodoFilter.active,
                label: Text(l10n.todosFilterActive),
              ),
              ButtonSegment(
                value: TodoFilter.completed,
                label: Text(l10n.todosFilterCompleted),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (Set<TodoFilter> newSelection) {
              setState(() {
                _filter = newSelection.first;
              });
            },
          ),
        ),
        Expanded(
          child: _filteredTodos.isEmpty
              ? Center(child: Text(l10n.todosEmpty))
              : ListView.builder(
                  itemCount: _filteredTodos.length,
                  itemBuilder: (context, index) {
                    final todo = _filteredTodos[index];
                    return _TodoListTile(todo: todo);
                  },
                ),
        ),
      ],
    );
  }
}

class _TodoListTile extends ConsumerWidget {
  final Todo todo;

  const _TodoListTile({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Checkbox(
        value: todo.completed,
        onChanged: (_) => ref.read(todosProvider.notifier).toggleComplete(todo.id),
      ),
      title: Text(
        todo.content,
        style: TextStyle(
          decoration: todo.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: todo.dueDate != null
          ? Text(
              'Due: ${todo.dueDate!.toLocal().toString().split(' ')[0]}',
              style: TextStyle(
                color: _isOverdue(todo.dueDate!) ? cs.error : cs.onSurfaceVariant,
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(todosProvider.notifier).deleteTodo(todo.id),
      ),
    );
  }

  bool _isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now());
  }
}

enum TodoFilter { all, active, completed, overdue }
```

- [ ] **Step 2: Add to navigation**

Add TodosScreen access from library screen (e.g., add to app bar or bottom nav). For now, add to library screen app bar:

```dart
IconButton(
  icon: const Icon(Icons.check_circle_outline),
  tooltip: l10n.libraryTodos,
  onPressed: () {
    HapticFeedback.lightImpact();
    Navigator.push<void>(context, SpringPageRoute(builder: (_) => const TodosScreen()));
  },
),
```

- [ ] **Step 3: Add localization strings**

Add to `lib/l10n/app_en.arb`:
```json
{
  "todosTitle": "Action Items",
  "todosFilterAll": "All",
  "todosFilterActive": "Active",
  "todosFilterCompleted": "Done",
  "todosEmpty": "No action items yet. They will appear after meeting summarization.",
  "libraryTodos": "Action Items"
}
```

Add to `lib/l10n/app_de.arb`:
```json
{
  "todosTitle": "Aufgaben",
  "todosFilterAll": "Alle",
  "todosFilterActive": "Offen",
  "todosFilterCompleted": "Erledigt",
  "todosEmpty": "Noch keine Aufgaben. Sie erscheinen nach der Meeting-Zusammenfassung.",
  "libraryTodos": "Aufgaben"
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/todos_screen.dart lib/screens/meeting_library_screen.dart lib/l10n/app_en.arb lib/l10n/app_de.arb
git commit -m "feat: add global Todos screen with filtering"
```

---

## Phase 3: Semantic Search (Deferred)

**Note**: This phase requires SQLite migration. See design spec for architecture. Implementation plan to be written when Phase 1-2 are complete and JSON file performance becomes a bottleneck.

---

## Phase 4: Audio Playback with Transcript Sync (Deferred)

**Note**: Implementation plan to be written when Phase 1-2 are complete.

---

## Testing Checklist

- [ ] Calendar permission request works on Android
- [ ] Calendar events sync and display on library screen
- [ ] Recording start suggests correct meeting title from calendar
- [ ] Todo extraction triggers after summarization
- [ ] Todos display in meeting detail tab
- [ ] Global todos screen shows all todos with filtering
- [ ] Todo completion toggle works
- [ ] Todo deletion works
- [ ] All existing functionality still works (record, transcribe, summarize, chat)

---

## Rollback Plan

If issues arise:
1. Calendar feature: Remove `device_calendar` dependency, revert UI changes
2. Todo feature: Remove todo extraction trigger, keep JSON files as-is
3. All data remains in JSON format — no migration needed

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-22-knowledge-hub-implementation.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?

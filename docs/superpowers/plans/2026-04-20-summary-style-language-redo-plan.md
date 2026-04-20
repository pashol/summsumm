# Meeting Summary Style, Language & Redo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multiple summaries per meeting with configurable style and language, browsable via horizontal chips, with a redo/add flow.

**Architecture:** Replace `Meeting.summary` (`String?`) with `Meeting.summaries` (`List<MeetingSummary>`). Add `SummaryStyle` enum with 4 values. Update `MeetingNotifier.summarize()` to accept style/language params and append language suffix to prompts. Add chip row UI to the summary tab. Add `summaryStyle` to `AppSettings`. Extract `_langSuffix` to shared utility.

**Tech Stack:** Flutter, Riverpod, Dart, flutter_markdown, shared_preferences

---

### Task 1: Create SummaryStyle enum and langSuffix utility

**Files:**
- Create: `lib/models/summary_style.dart`
- Modify: `lib/models/app_settings.dart`

- [ ] **Step 1: Create SummaryStyle enum**

Create `lib/models/summary_style.dart`:

```dart
import 'meeting.dart';

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
```

- [ ] **Step 2: Create langSuffix utility**

Add to `lib/models/summary_style.dart` (below the enum):

```dart
String langSuffix(String language, String subject) {
  if (language == 'Same as input') return '';
  return '\n\nIMPORTANT: The summary must be in $language.';
}
```

- [ ] **Step 3: Update kSupportedLanguages**

In `lib/models/app_settings.dart`, change `kSupportedLanguages` from:

```dart
const kSupportedLanguages = [
  'English',
  'German',
  ...
];
```

to:

```dart
const kSupportedLanguages = [
  'Same as input',
  'English',
  'German',
  'French',
  'Spanish',
  'Italian',
  'Portuguese',
  'Russian',
  'Chinese',
  'Japanese',
  'Korean',
  'Arabic',
  'Hindi',
  'Dutch',
  'Polish',
  'Turkish',
];
```

- [ ] **Step 4: Change AppSettings.language default**

In `lib/models/app_settings.dart`, change `AppSettings.defaults()`:

```dart
factory AppSettings.defaults() => const AppSettings(
      provider: 'openrouter',
      openrouterModel: '',
      openaiModel: '',
      language: 'Same as input',
      ttsSpeed: 1.0,
      openaiKey: '',
      openrouterKey: '',
      debugMode: false,
    );
```

- [ ] **Step 5: Add summaryStyle to AppSettings**

In `lib/models/app_settings.dart`:

Add field `final String summaryStyle;` to the class.

Add to constructor: `required this.summaryStyle,`

Change `AppSettings.defaults()` to include `summaryStyle: 'structured',`

Add to `copyWith`: `String? summaryStyle,` and `summaryStyle: summaryStyle ?? this.summaryStyle,`

Add to `toJson`: `'summaryStyle': summaryStyle,`

Add to `fromJson`: `summaryStyle: json['summaryStyle'] as String? ?? 'structured',`

Add to `==`: `other.summaryStyle == summaryStyle &&`

Add to `hashCode`: `summaryStyle,`

- [ ] **Step 6: Update Settings.setLanguage validation**

In `lib/providers/settings_provider.dart`, `setLanguage` already validates against `kSupportedLanguages`. Since `'Same as input'` is now in the list, it will work. No change needed to the validation logic itself.

- [ ] **Step 7: Commit**

```bash
git add lib/models/summary_style.dart lib/models/app_settings.dart
git commit -m "feat: add SummaryStyle enum, langSuffix utility, and summaryStyle to AppSettings"
```

---

### Task 2: Create MeetingSummary class and update Meeting model

**Files:**
- Modify: `lib/models/meeting.dart`
- Test: `test/models/meeting_test.dart`

- [ ] **Step 1: Write tests for MeetingSummary and updated Meeting**

Create `test/models/meeting_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';

void main() {
  group('MeetingSummary', () {
    test('toJson and fromJson round-trip', () {
      final summary = MeetingSummary(
        id: 'abc123',
        style: SummaryStyle.concise,
        language: 'German',
        content: '## Key points\n- Point 1',
        createdAt: DateTime.utc(2026, 4, 20, 10, 0),
      );

      final json = summary.toJson();
      final restored = MeetingSummary.fromJson(json);

      expect(restored.id, summary.id);
      expect(restored.style, summary.style);
      expect(restored.language, summary.language);
      expect(restored.content, summary.content);
      expect(restored.createdAt, summary.createdAt);
    });
  });

  group('Meeting with summaries', () {
    test('toJson includes summaries list', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path/to/audio.m4a',
        title: 'Test Meeting',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.structured,
            language: 'English',
            content: '## Decisions\n- Decision 1',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      final json = meeting.toJson();
      expect(json['summaries'], isA<List>());
      expect(json['summaries'], hasLength(1));
      expect(json['summaries'][0]['id'], 's1');
      expect(json['summaries'][0]['style'], 'structured');
    });

    test('fromJson restores summaries list', () {
      final json = {
        'id': 'm1',
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300,
        'audioPath': '/path/to/audio.m4a',
        'title': 'Test Meeting',
        'status': 'done',
        'summaries': [
          {
            'id': 's1',
            'style': 'concise',
            'language': 'German',
            'content': '## Key points',
            'createdAt': '2026-04-20T10:00:00.000Z',
          },
        ],
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.summaries, hasLength(1));
      expect(meeting.summaries[0].style, SummaryStyle.concise);
      expect(meeting.summaries[0].language, 'German');
    });

    test('migrates old summary field to summaries list', () {
      final json = {
        'id': 'm1',
        'createdAt': '2026-04-20T10:00:00.000Z',
        'durationSec': 300,
        'audioPath': '/path/to/audio.m4a',
        'title': 'Old Meeting',
        'status': 'done',
        'summary': '## Old summary content',
      };

      final meeting = Meeting.fromJson(json);
      expect(meeting.summaries, hasLength(1));
      expect(meeting.summaries[0].style, SummaryStyle.structured);
      expect(meeting.summaries[0].language, 'Same as input');
      expect(meeting.summaries[0].content, '## Old summary content');
    });

    test('summary getter returns first summary content', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.concise,
            language: 'English',
            content: 'First summary',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      expect(meeting.summary, 'First summary');
    });

    test('summary getter returns null when no summaries', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.transcribed,
      );

      expect(meeting.summary, isNull);
    });

    test('copyWith preserves summaries', () {
      final meeting = Meeting(
        id: 'm1',
        createdAt: DateTime.utc(2026, 4, 20),
        durationSec: 300,
        audioPath: '/path',
        title: 'Test',
        status: MeetingStatus.done,
        summaries: [
          MeetingSummary(
            id: 's1',
            style: SummaryStyle.concise,
            language: 'English',
            content: 'Content',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      );

      final updated = meeting.copyWith(status: MeetingStatus.summarizing);
      expect(updated.summaries, hasLength(1));
      expect(updated.status, MeetingStatus.summarizing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/meeting_test.dart`
Expected: FAIL (MeetingSummary doesn't exist yet, Meeting.summaries doesn't exist)

- [ ] **Step 3: Implement MeetingSummary and update Meeting**

Replace `lib/models/meeting.dart` with:

```dart
import 'dart:convert';
import 'summary_style.dart';

enum MeetingType { meeting, document }

class MeetingSummary {
  final String id;
  final SummaryStyle style;
  final String language;
  final String content;
  final DateTime createdAt;

  const MeetingSummary({
    required this.id,
    required this.style,
    required this.language,
    required this.content,
    required this.createdAt,
  });

  MeetingSummary copyWith({
    String? id,
    SummaryStyle? style,
    String? language,
    String? content,
    DateTime? createdAt,
  }) {
    return MeetingSummary(
      id: id ?? this.id,
      style: style ?? this.style,
      language: language ?? this.language,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'style': style.name,
      'language': language,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'] as String,
      style: SummaryStyle.values.firstWhere(
        (e) => e.name == json['style'],
        orElse: () => SummaryStyle.structured,
      ),
      language: json['language'] as String? ?? 'Same as input',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Meeting {
  final String id;
  final DateTime createdAt;
  final int durationSec;
  final String audioPath;
  final String title;
  final String? transcript;
  final MeetingStatus status;
  final String? lastError;
  final String? provider;
  final bool archived;
  final MeetingType type;
  final String? transcriptionLog;
  final String? transcriptionStatus;
  final double? transcriptionProgress;
  final List<MeetingSummary> summaries;

  const Meeting({
    required this.id,
    required this.createdAt,
    required this.durationSec,
    required this.audioPath,
    required this.title,
    this.transcript,
    required this.status,
    this.lastError,
    this.provider,
    this.archived = false,
    this.type = MeetingType.meeting,
    this.transcriptionLog,
    this.transcriptionStatus,
    this.transcriptionProgress,
    this.summaries = const [],
  });

  /// Convenience getter for backward compatibility.
  /// Returns the content of the first summary, or null if none exist.
  String? get summary => summaries.isEmpty ? null : summaries.first.content;

  Meeting copyWith({
    String? id,
    DateTime? createdAt,
    int? durationSec,
    String? audioPath,
    String? title,
    String? transcript,
    MeetingStatus? status,
    String? lastError,
    bool clearLastError = false,
    String? provider,
    bool? archived,
    MeetingType? type,
    String? transcriptionLog,
    bool clearTranscriptionStatus = false,
    String? transcriptionStatus,
    bool clearTranscriptionProgress = false,
    double? transcriptionProgress,
    List<MeetingSummary>? summaries,
  }) {
    return Meeting(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationSec: durationSec ?? this.durationSec,
      audioPath: audioPath ?? this.audioPath,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      provider: provider ?? this.provider,
      archived: archived ?? this.archived,
      type: type ?? this.type,
      transcriptionLog: transcriptionLog ?? this.transcriptionLog,
      transcriptionStatus: clearTranscriptionStatus ? null : (transcriptionStatus ?? this.transcriptionStatus),
      transcriptionProgress: clearTranscriptionProgress ? null : (transcriptionProgress ?? this.transcriptionProgress),
      summaries: summaries ?? this.summaries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'durationSec': durationSec,
      'audioPath': audioPath,
      'title': title,
      'transcript': transcript,
      'status': status.name,
      'lastError': lastError,
      'provider': provider,
      'archived': archived,
      'type': type.name,
      'transcriptionLog': transcriptionLog,
      'transcriptionStatus': transcriptionStatus,
      'transcriptionProgress': transcriptionProgress,
      'summaries': summaries.map((s) => s.toJson()).toList(),
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    final summariesJson = json['summaries'];
    List<MeetingSummary> summaries = [];
    if (summariesJson is List) {
      summaries = summariesJson
          .map((s) => MeetingSummary.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    // Backward compatibility: migrate old summary field
    final oldSummary = json['summary'] as String?;
    if (oldSummary != null && oldSummary.isNotEmpty && summaries.isEmpty) {
      summaries = [
        MeetingSummary(
          id: 'migrated_${json['id']}',
          style: SummaryStyle.structured,
          language: 'Same as input',
          content: oldSummary,
          createdAt: DateTime.parse(json['createdAt'] as String),
        ),
      ];
    }

    return Meeting(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationSec: json['durationSec'] as int,
      audioPath: json['audioPath'] as String,
      title: json['title'] as String,
      transcript: json['transcript'] as String?,
      status: MeetingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MeetingStatus.recorded,
      ),
      lastError: json['lastError'] as String?,
      provider: json['provider'] as String?,
      archived: json['archived'] as bool? ?? false,
      type: MeetingType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MeetingType.meeting,
      ),
      transcriptionLog: json['transcriptionLog'] as String?,
      transcriptionStatus: json['transcriptionStatus'] as String?,
      transcriptionProgress: (json['transcriptionProgress'] as num?)?.toDouble(),
      summaries: summaries,
    );
  }
}

enum MeetingStatus {
  recorded,
  transcribing,
  transcribed,
  summarizing,
  done,
  failed
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/meeting_test.dart -v`
Expected: All 7 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/models/meeting.dart lib/models/summary_style.dart test/models/meeting_test.dart
git commit -m "feat: add MeetingSummary class, summaries list, and backward compat migration"
```

---

### Task 3: Update MeetingNotifier.summarize() with style/language

**Files:**
- Modify: `lib/providers/meeting_provider.dart`
- Test: `test/providers/meeting_provider_test.dart`

- [ ] **Step 1: Write tests for summarize with style/language**

Create `test/providers/meeting_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/summary_style.dart';

void main() {
  group('SummaryStyle', () {
    test('displayName returns correct labels', () {
      expect(SummaryStyle.concise.displayName, 'Concise');
      expect(SummaryStyle.brief.displayName, 'Brief');
      expect(SummaryStyle.detailed.displayName, 'Detailed');
      expect(SummaryStyle.structured.displayName, 'Structured');
    });

    test('forType returns correct styles for meetings', () {
      final styles = SummaryStyle.forType(MeetingType.meeting);
      expect(styles, [SummaryStyle.concise, SummaryStyle.detailed, SummaryStyle.structured]);
      expect(styles, isNot(contains(SummaryStyle.brief)));
    });

    test('forType returns correct styles for documents', () {
      final styles = SummaryStyle.forType(MeetingType.document);
      expect(styles, [SummaryStyle.concise, SummaryStyle.brief, SummaryStyle.detailed]);
      expect(styles, isNot(contains(SummaryStyle.structured)));
    });
  });

  group('langSuffix', () {
    test('returns empty for Same as input', () {
      expect(langSuffix('Same as input', 'Summary'), '');
    });

    test('returns suffix for other languages', () {
      final result = langSuffix('German', 'Summary');
      expect(result, contains('German'));
      expect(result, contains('IMPORTANT'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/meeting_provider_test.dart`
Expected: FAIL (langSuffix not imported)

- [ ] **Step 3: Fix import in test**

Add to top of `test/providers/meeting_provider_test.dart`:

```dart
import 'package:summsumm/models/summary_style.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/providers/meeting_provider_test.dart -v`
Expected: All tests pass

- [ ] **Step 5: Update MeetingNotifier.summarize()**

Replace `lib/providers/meeting_provider.dart` with:

```dart
import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/ai_service.dart';
import 'package:summsumm/services/voice_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());

final meetingProvider = NotifierProvider.family<MeetingNotifier, Meeting, String>(
  MeetingNotifier.new,
);

class MeetingNotifier extends FamilyNotifier<Meeting, String> {
  DateTime? _lastSave;

  @override
  Meeting build(String meetingId) {
    ref.listen(meetingLibraryProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });
    ref.listen(archivedMeetingsProvider, (prev, next) {
      final meeting = _findIn(next, meetingId);
      if (meeting != null) state = meeting;
    });

    final library = ref.read(meetingLibraryProvider);
    final archived = ref.read(archivedMeetingsProvider);
    return _findIn(library, meetingId) ??
        _findIn(archived, meetingId) ??
        _placeholder(meetingId);
  }

  Meeting? _findIn(AsyncValue<List<Meeting>> value, String meetingId) {
    return value.whenOrNull(
      data: (meetings) {
        try {
          return meetings.firstWhere((m) => m.id == meetingId);
        } catch (_) {
          return null;
        }
      },
    );
  }

  Meeting _placeholder(String meetingId) => Meeting(
        id: meetingId,
        createdAt: DateTime.now(),
        durationSec: 0,
        audioPath: '',
        title: '',
        status: MeetingStatus.recorded,
      );

  bool get _isPlaceholder => state.title.isEmpty && state.audioPath.isEmpty;

  Future<bool> _hasConnectivity(String provider) async {
    final url = provider == 'openai'
        ? Uri.parse('https://api.openai.com')
        : Uri.parse('https://openrouter.ai');
    try {
      final client = http.Client();
      try {
        final response = await client.head(url).timeout(const Duration(seconds: 5));
        return response.statusCode < 500;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  void _throttledSave(Meeting meeting) {
    final now = DateTime.now();
    if (_lastSave == null || now.difference(_lastSave!).inMilliseconds > 500) {
      _lastSave = now;
      final repository = ref.read(meetingRepositoryProvider);
      repository.save(meeting);
      ref.read(meetingLibraryProvider.notifier).refresh();
    }
  }

  Future<void> transcribe({bool diarize = false}) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final voiceService = ref.read(voiceServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(status: MeetingStatus.transcribing, clearLastError: true, transcriptionStatus: 'Validating audio…', transcriptionProgress: null);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final apiKey = await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '';
      final transcript = await voiceService.transcribeFile(
        meeting.audioPath,
        settings.provider,
        apiKey,
        diarize: diarize,
        onProgress: (status, progress) {
          final determinate = progress != null && progress >= 0.3;
          state = state.copyWith(
            transcriptionStatus: status,
            transcriptionProgress: determinate ? progress : null,
          );
          _throttledSave(state);
        },
      );

      state = state.copyWith(
        transcript: transcript,
        status: MeetingStatus.transcribed,
        provider: settings.provider,
        clearLastError: true,
        clearTranscriptionStatus: true,
        clearTranscriptionProgress: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      rethrow;
    }
  }

  Future<void> summarize({SummaryStyle? style, String? language}) async {
    final meeting = state;
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);
    final repository = ref.read(meetingRepositoryProvider);

    final resolvedStyle = style ?? _resolveStyle(settings.summaryStyle, meeting.type);
    final resolvedLanguage = language ?? settings.language;

    if (!await _hasConnectivity(settings.provider)) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: 'No internet connection. Please connect to a network and try again.',
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      return;
    }

    state = meeting.copyWith(status: MeetingStatus.summarizing, clearLastError: true);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();

    try {
      final langSuffixText = langSuffix(resolvedLanguage, 'The summary');
      final systemPrompt = _promptForStyle(resolvedStyle, meeting.type, langSuffixText);

      String summary = '';
      final newSummary = MeetingSummary(
        id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
        style: resolvedStyle,
        language: resolvedLanguage,
        content: '',
        createdAt: DateTime.now(),
      );

      if (meeting.type == MeetingType.document) {
        final file = io.File(meeting.audioPath);
        final summaryStream = aiService.streamCompletionWithFile(
          file: file,
          model: settings.activeModel,
          prompt: systemPrompt,
          provider: settings.provider,
          apiKey: await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '',
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          final updated = newSummary.copyWith(content: summary);
          state = state.copyWith(summaries: [...meeting.summaries, updated]);
        }
      } else {
        final summaryStream = aiService.streamCompletion(
          model: settings.activeModel,
          messages: [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': meeting.transcript ?? '',
            },
          ],
          apiKey: await ref.read(settingsProvider.notifier).getApiKey(settings.provider) ?? '',
          provider: settings.provider,
        );
        await for (final chunk in summaryStream) {
          summary += chunk;
          final updated = newSummary.copyWith(content: summary);
          state = state.copyWith(summaries: [...meeting.summaries, updated]);
        }
      }

      state = state.copyWith(
        status: MeetingStatus.done,
        clearLastError: true,
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      state = meeting.copyWith(
        status: MeetingStatus.failed,
        lastError: e.toString(),
      );
      await repository.save(state);
      ref.read(meetingLibraryProvider.notifier).refresh();
      rethrow;
    }
  }

  SummaryStyle _resolveStyle(String settingsStyle, MeetingType type) {
    final parsed = SummaryStyle.values.firstWhere(
      (s) => s.name == settingsStyle,
      orElse: () => SummaryStyle.structured,
    );
    final available = SummaryStyle.forType(type);
    if (available.contains(parsed)) return parsed;
    return available.first;
  }

  String _promptForStyle(SummaryStyle style, MeetingType type, String langSuffixText) {
    switch (style) {
      case SummaryStyle.concise:
        return 'You are an expert summarizer. Produce a brief summary with 3-5 bullet points covering only the key points. Do not elaborate. Do not wrap output in a code block.$langSuffixText';
      case SummaryStyle.brief:
        return 'You are an expert document summarizer. Write a short paragraph summarizing the key points of this document. Do not use bullet points or headers. Do not wrap output in a code block.$langSuffixText';
      case SummaryStyle.detailed:
        return 'You are an expert summarizer. Produce a comprehensive summary with thorough coverage of each topic. Include context and reasoning. Use ## headers for topics, paragraphs for detail. Do not wrap output in a code block.$langSuffixText';
      case SummaryStyle.structured:
        return 'You are an expert meeting summarizer. Extract: 1. Key decisions made 2. Action items with owners 3. Open questions 4. Important context. Use markdown headers and bullet points. Do not wrap output in a code block. Be concise and factual.$langSuffixText';
    }
  }

  Future<void> retry() async {
    final meeting = state;
    if (meeting.status == MeetingStatus.failed) {
      if (meeting.transcript == null) {
        await transcribe();
      } else if (meeting.summaries.isEmpty) {
        await summarize();
      }
    }
  }

  Future<void> rename(String newTitle) async {
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(title: newTitle);
    await repository.save(state);
  }

  Future<void> delete() async {
    final repository = ref.read(meetingRepositoryProvider);
    await repository.delete(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
  }

  Future<void> archive() async {
    if (_isPlaceholder) return;
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(archived: true);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    ref.read(archivedMeetingsProvider.notifier).refresh();
  }

  Future<void> unarchive() async {
    if (_isPlaceholder) return;
    final repository = ref.read(meetingRepositoryProvider);
    state = state.copyWith(archived: false);
    await repository.save(state);
    ref.read(meetingLibraryProvider.notifier).refresh();
    ref.read(archivedMeetingsProvider.notifier).refresh();
  }
}
```

- [ ] **Step 6: Run all tests**

Run: `flutter test -v`
Expected: All tests pass

- [ ] **Step 7: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/providers/meeting_provider.dart test/providers/meeting_provider_test.dart
git commit -m "feat: update summarize() with style/language params and prompt templates"
```

---

### Task 4: Add setSummaryStyle to SettingsProvider

**Files:**
- Modify: `lib/providers/settings_provider.dart`

- [ ] **Step 1: Add setSummaryStyle method**

In `lib/providers/settings_provider.dart`, add after `setLanguage`:

```dart
  Future<void> setSummaryStyle(String style) async {
    final next = state.copyWith(summaryStyle: style);
    state = next;
    await _persist(next);
  }
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/settings_provider.dart
git commit -m "feat: add setSummaryStyle to SettingsProvider"
```

---

### Task 5: Add Summary Style dropdown to Settings screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add Summary Style dropdown**

In `lib/screens/settings_screen.dart`, find the Summary `_SectionCard` (around line 321) and replace it:

```dart
          _SectionCard(
            title: 'Summary',
            icon: Icons.summarize_outlined,
            children: [
              DropdownButtonFormField<String>(
                initialValue: settings.summaryStyle,
                decoration: const InputDecoration(
                  labelText: 'Style',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_bulleted_outlined),
                ),
                items: SummaryStyle.values
                    .map((s) => DropdownMenuItem(value: s.name, child: Text(s.displayName)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) notifier.setSummaryStyle(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.language,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                items: kSupportedLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (l) {
                  if (l != null) notifier.setLanguage(l);
                },
              ),
            ],
          ),
```

- [ ] **Step 2: Add import for SummaryStyle**

Add to top of `lib/screens/settings_screen.dart`:

```dart
import '../models/summary_style.dart';
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add Summary style dropdown to settings screen"
```

---

### Task 6: Update SummaryProvider to use shared langSuffix

**Files:**
- Modify: `lib/providers/summary_provider.dart`

- [ ] **Step 1: Replace _langSuffix with shared langSuffix**

In `lib/providers/summary_provider.dart`:

Remove the local `_langSuffix` function (lines 22-25).

Add import at top:

```dart
import '../models/summary_style.dart';
```

Replace all occurrences of `_langSuffix` with `langSuffix` (the shared utility).

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/summary_provider.dart
git commit -m "refactor: use shared langSuffix utility in SummaryProvider"
```

---

### Task 7: Update meeting_detail_screen.dart summary tab UI

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Add imports**

Add to top of `lib/screens/meeting_detail_screen.dart`:

```dart
import '../models/summary_style.dart';
```

- [ ] **Step 2: Add state variables**

In `_MeetingDetailScreenState`, add after `_diarize`:

```dart
  SummaryStyle? _selectedStyle;
  String? _selectedLanguage;
  bool _showAddControls = false;
```

- [ ] **Step 3: Replace _buildSummaryTab**

Replace the entire `_buildSummaryTab` method with:

```dart
  Widget _buildSummaryTab(Meeting meeting, MeetingNotifier provider) {
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => provider.summarize(),
                child: const Text('Summarize'),
              ),
            ),
          );
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No transcript yet.\nGo to the Transcript tab to transcribe.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () => provider.summarize(),
              child: const Text('Summarize'),
            ),
          ),
        );
      case MeetingStatus.summarizing:
        return _buildSummarizingContent(meeting);
      case MeetingStatus.done:
        return _buildDoneContent(meeting, provider);
      case MeetingStatus.failed:
        return _buildFailedContent(meeting, provider);
    }
  }

  Widget _buildSummarizingContent(Meeting meeting) {
    final currentSummary = meeting.summaries.lastOrNull;
    final content = currentSummary?.content ?? '';

    if (content.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Summarizing…'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (meeting.summaries.length > 1)
          _buildChipRow(meeting, null),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'Summarizing…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MarkdownBody(data: content),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneContent(Meeting meeting, MeetingNotifier provider) {
    return Column(
      children: [
        _buildChipRow(meeting, provider, null),
        if (_showAddControls) _buildAddControls(meeting, provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(data: meeting.summary ?? ''),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedContent(Meeting meeting, MeetingNotifier provider) {
    if (meeting.summaries.isNotEmpty) {
      return Column(
        children: [
          _buildChipRow(meeting, provider, null),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meeting.lastError ?? 'An error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: provider.retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
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

  Widget _buildChipRow(Meeting meeting, MeetingNotifier? provider) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: meeting.summaries.length + 1,
        itemBuilder: (context, index) {
          if (index == meeting.summaries.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: const Icon(Icons.add, size: 18),
                selected: _showAddControls,
                onSelected: (_) => setState(() => _showAddControls = !_showAddControls),
              ),
            );
          }

          final summary = meeting.summaries[index];
          final styleCount = meeting.summaries.where((s) => s.style == summary.style).toList();
          final styleIndex = styleCount.indexOf(summary);
          final chipLabel = styleCount.length > 1
              ? '${summary.style.displayName} ${styleIndex + 1}'
              : summary.style.displayName;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(chipLabel),
              selected: summary == meeting.summaries.first,
              onSelected: (_) {
                // Selection is implicit via chip tap
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddControls(Meeting meeting, MeetingNotifier provider) {
    final settings = ref.watch(settingsProvider);
    final availableStyles = SummaryStyle.forType(meeting.type);

    _selectedStyle ??= _resolveInitialStyle(settings.summaryStyle, meeting.type);
    _selectedLanguage ??= settings.language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<SummaryStyle>(
            value: _selectedStyle,
            decoration: const InputDecoration(
              labelText: 'Style',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: availableStyles
                .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedStyle = v);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: kSupportedLanguages
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedLanguage = v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final style = _selectedStyle!;
                    final language = _selectedLanguage!;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Generate Summary'),
                        content: Text('Generate a new summary in $language with $style style?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _showAddControls = false;
                                _selectedStyle = null;
                                _selectedLanguage = null;
                              });
                              provider.summarize(style: style, language: language);
                            },
                            child: const Text('Generate'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Summarize'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _showAddControls = false;
                  _selectedStyle = null;
                  _selectedLanguage = null;
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SummaryStyle _resolveInitialStyle(String settingsStyle, MeetingType type) {
    final parsed = SummaryStyle.values.firstWhere(
      (s) => s.name == settingsStyle,
      orElse: () => SummaryStyle.structured,
    );
    final available = SummaryStyle.forType(type);
    if (available.contains(parsed)) return parsed;
    return available.first;
  }
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart
git commit -m "feat: add chip row and add controls to meeting summary tab"
```

---

### Task 8: Update meeting_share_sheet.dart for summaries

**Files:**
- Modify: `lib/widgets/meeting_share_sheet.dart`

- [ ] **Step 1: Update share sheet to use summaries**

In `lib/widgets/meeting_share_sheet.dart`, replace the summary sharing section (lines 38-43):

```dart
          if (meeting.summaries.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Share Summary'),
              onTap: () => _shareText(context, meeting.summary!),
            ),
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/meeting_share_sheet.dart
git commit -m "fix: update share sheet to use summaries list"
```

---

### Task 9: Update meeting_chat_provider to use summaries

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart` (line 451)

- [ ] **Step 1: Update _sendChatMessage**

In `lib/screens/meeting_detail_screen.dart`, in `_sendChatMessage`, change:

```dart
      summary: meeting.summary,
```

This already works via the convenience getter. No change needed.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

---

### Task 10: Run full verification

- [ ] **Step 1: Run all tests**

Run: `flutter test -v`
Expected: All tests pass

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: complete meeting summary style/language/redo feature"
```

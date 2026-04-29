import 'dart:convert';
import 'summary_style.dart';
import 'transcription_config.dart';

export 'summary_style.dart' show MeetingType;

class MeetingSummary {
  final String id;
  final SummaryStyle style;
  final String language;
  final String content;
  final DateTime createdAt;
  final String? customPromptId;

  const MeetingSummary({
    required this.id,
    required this.style,
    required this.language,
    required this.content,
    required this.createdAt,
    this.customPromptId,
  });

  MeetingSummary copyWith({
    String? id,
    SummaryStyle? style,
    String? language,
    String? content,
    DateTime? createdAt,
    String? customPromptId,
  }) {
    return MeetingSummary(
      id: id ?? this.id,
      style: style ?? this.style,
      language: language ?? this.language,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      customPromptId: customPromptId ?? this.customPromptId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'style': style.name,
      'language': language,
      'content': content,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'customPromptId': customPromptId,
    };
  }

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'] as String? ?? 'unknown',
      style: SummaryStyle.values.firstWhere(
        (e) => e.name == json['style'],
        orElse: () => SummaryStyle.structured,
      ),
      language: json['language'] as String? ?? 'Same as input',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      customPromptId: json['customPromptId'] as String?,
    );
  }
}

class Meeting {
  final String id;
  final DateTime createdAt;
  final int durationSec;
  final String audioPath;
  final String title;
  final String? rawTranscript;
  final String? cleanedTranscript;
  final bool cleanupEnabled;
  final MeetingStatus status;
  final String? lastError;
  final String? provider;
  final bool archived;
  final MeetingType type;
  final String? transcriptionLog;
  final String? transcriptionStatus;
  final double? transcriptionProgress;
  final List<MeetingSummary> summaries;
  final List<SpeakerSegment>? speakerSegments;
  final bool wasLiveTranscribed;

  const Meeting({
    required this.id,
    required this.createdAt,
    required this.durationSec,
    required this.audioPath,
    required this.title,
    this.rawTranscript,
    this.cleanedTranscript,
    this.cleanupEnabled = true,
    required this.status,
    this.lastError,
    this.provider,
    this.archived = false,
    this.type = MeetingType.meeting,
    this.transcriptionLog,
    this.transcriptionStatus,
    this.transcriptionProgress,
    this.summaries = const [],
    this.speakerSegments,
    this.wasLiveTranscribed = false,
  });

  /// Convenience getter for backward compatibility.
  /// Returns the content of the first summary, or null if none exist.
  String? get summary => summaries.isEmpty ? null : summaries.first.content;

  /// Computed transcript: returns cleaned version if available, otherwise raw.
  String? get transcript => cleanedTranscript ?? rawTranscript;

  Meeting copyWith({
    String? id,
    DateTime? createdAt,
    int? durationSec,
    String? audioPath,
    String? title,
    String? rawTranscript,
    String? cleanedTranscript,
    bool? cleanupEnabled,
    MeetingStatus? status,
    String? lastError,
    bool clearLastError = false,
    String? provider,
    bool clearProvider = false,
    bool clearTranscriptionLog = false,
    bool? archived,
    MeetingType? type,
    String? transcriptionLog,
    bool clearTranscriptionStatus = false,
    String? transcriptionStatus,
    bool clearTranscriptionProgress = false,
    double? transcriptionProgress,
    List<MeetingSummary>? summaries,
    List<SpeakerSegment>? speakerSegments,
    bool? wasLiveTranscribed,
    bool clearRawTranscript = false,
    bool clearCleanedTranscript = false,
    bool clearSpeakerSegments = false,
  }) {
    return Meeting(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationSec: durationSec ?? this.durationSec,
      audioPath: audioPath ?? this.audioPath,
      title: title ?? this.title,
      rawTranscript: clearRawTranscript ? null : (rawTranscript ?? this.rawTranscript),
      cleanedTranscript: clearCleanedTranscript ? null : (cleanedTranscript ?? this.cleanedTranscript),
      cleanupEnabled: cleanupEnabled ?? this.cleanupEnabled,
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      provider: clearProvider ? null : (provider ?? this.provider),
      archived: archived ?? this.archived,
      type: type ?? this.type,
      transcriptionLog: clearTranscriptionLog ? null : (transcriptionLog ?? this.transcriptionLog),
      transcriptionStatus: clearTranscriptionStatus ? null : (transcriptionStatus ?? this.transcriptionStatus),
      transcriptionProgress: clearTranscriptionProgress ? null : (transcriptionProgress ?? this.transcriptionProgress),
      summaries: summaries ?? this.summaries,
      speakerSegments: clearSpeakerSegments ? null : (speakerSegments ?? this.speakerSegments),
      wasLiveTranscribed: wasLiveTranscribed ?? this.wasLiveTranscribed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'durationSec': durationSec,
      'audioPath': audioPath,
      'title': title,
      'rawTranscript': rawTranscript,
      'cleanedTranscript': cleanedTranscript,
      'cleanupEnabled': cleanupEnabled,
      'status': status.name,
      'lastError': lastError,
      'provider': provider,
      'archived': archived,
      'type': type.name,
      'transcriptionLog': transcriptionLog,
      'transcriptionStatus': transcriptionStatus,
      'transcriptionProgress': transcriptionProgress,
      'summaries': summaries.map((s) => s.toJson()).toList(),
      'speakerSegments': speakerSegments?.map((s) => s.toJson()).toList(),
      'wasLiveTranscribed': wasLiveTranscribed,
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
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        ),
      ];
    }

    return Meeting(
      id: json['id'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      durationSec: (json['durationSec'] as num).toInt(),
      audioPath: json['audioPath'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      rawTranscript: json['rawTranscript'] as String?,
      cleanedTranscript: json['cleanedTranscript'] as String?,
      cleanupEnabled: json['cleanupEnabled'] as bool? ?? false,
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
      speakerSegments: (json['speakerSegments'] as List<dynamic>?)
          ?.map((s) => SpeakerSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      wasLiveTranscribed: json['wasLiveTranscribed'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Meeting.fromJsonString(String s) =>
      Meeting.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

enum MeetingStatus {
  recorded,
  transcribing,
  transcribed,
  summarizing,
  done,
  failed
}

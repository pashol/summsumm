import 'dart:convert';
import 'summary_style.dart';

export 'summary_style.dart' show MeetingType;

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
      'createdAt': createdAt.toUtc().toIso8601String(),
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
      'createdAt': createdAt.toUtc().toIso8601String(),
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

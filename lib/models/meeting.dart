import 'dart:convert';

enum MeetingType { meeting, document }

class Meeting {
  final String id;
  final DateTime createdAt;
  final int durationSec;
  final String audioPath;
  final String title;
  final String? transcript;
  final String? summary;
  final MeetingStatus status;
  final String? lastError;
  final String? provider;
  final bool archived;
  final MeetingType type;
  final String? transcriptionLog;
  final String? transcriptionStatus;
  final double? transcriptionProgress;

  const Meeting({
    required this.id,
    required this.createdAt,
    required this.durationSec,
    required this.audioPath,
    required this.title,
    this.transcript,
    this.summary,
    required this.status,
    this.lastError,
    this.provider,
    this.archived = false,
    this.type = MeetingType.meeting,
    this.transcriptionLog,
    this.transcriptionStatus,
    this.transcriptionProgress,
  });

  Meeting copyWith({
    String? id,
    DateTime? createdAt,
    int? durationSec,
    String? audioPath,
    String? title,
    String? transcript,
    String? summary,
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
  }) {
    return Meeting(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationSec: durationSec ?? this.durationSec,
      audioPath: audioPath ?? this.audioPath,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      provider: provider ?? this.provider,
      archived: archived ?? this.archived,
      type: type ?? this.type,
      transcriptionLog: transcriptionLog ?? this.transcriptionLog,
      transcriptionStatus: clearTranscriptionStatus ? null : (transcriptionStatus ?? this.transcriptionStatus),
      transcriptionProgress: clearTranscriptionProgress ? null : (transcriptionProgress ?? this.transcriptionProgress),
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
      'summary': summary,
      'status': status.name,
      'lastError': lastError,
      'provider': provider,
      'archived': archived,
      'type': type.name,
      'transcriptionLog': transcriptionLog,
      'transcriptionStatus': transcriptionStatus,
      'transcriptionProgress': transcriptionProgress,
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationSec: json['durationSec'] as int,
      audioPath: json['audioPath'] as String,
      title: json['title'] as String,
      transcript: json['transcript'] as String?,
      summary: json['summary'] as String?,
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

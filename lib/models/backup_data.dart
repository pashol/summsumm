import 'dart:convert';
import 'app_settings.dart';
import 'meeting.dart';

class BackupData {
  final String version;
  final DateTime exportedAt;
  final AppSettings? settings;
  final String? openrouterKey;
  final String? openaiKey;
  final List<Meeting> meetings;
  final Map<String, String>? audioFiles;

  const BackupData({
    required this.version,
    required this.exportedAt,
    this.settings,
    this.openrouterKey,
    this.openaiKey,
    required this.meetings,
    this.audioFiles,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'settings': settings?.toJson(),
      'openrouterKey': openrouterKey,
      'openaiKey': openaiKey,
      'meetings': meetings.map((m) => m.toJson()).toList(),
      'audioFiles': audioFiles,
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final settingsJson = json['settings'] as Map<String, dynamic>?;
    final meetingsJson = json['meetings'] as List<dynamic>?;
    final audioFilesJson = json['audioFiles'] as Map<String, dynamic>?;

    return BackupData(
      version: json['version'] as String? ?? '1.0',
      exportedAt: DateTime.parse(json['exportedAt'] as String).toUtc(),
      settings: settingsJson != null ? AppSettings.fromJson(settingsJson) : null,
      openrouterKey: json['openrouterKey'] as String?,
      openaiKey: json['openaiKey'] as String?,
      meetings: meetingsJson
              ?.map((m) => Meeting.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      audioFiles: audioFilesJson?.map(
        (key, value) => MapEntry(key, value as String),
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BackupData.fromJsonString(String s) =>
      BackupData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

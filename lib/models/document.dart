class Document {
  final String id;
  final String text;
  final String? title;
  final String? uri;
  final String? name;
  final int? size;
  final String? error;
  final String? type;
  final String? path;
  final int? durationMs;

  Document({
    required this.id,
    required this.text,
    this.title,
    this.uri,
    this.name,
    this.size,
    this.error,
    this.type,
    this.path,
    this.durationMs,
  });

  bool get isAudio => type == 'audio' && path != null;
  bool get isBackup => type == 'backup';
  bool get isPdf => uri != null && uri!.isNotEmpty && type != 'audio' && type != 'backup';
  bool get hasError => error != null && error!.isNotEmpty;
}

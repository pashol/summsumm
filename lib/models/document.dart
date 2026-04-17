class Document {
  final String id;
  final String text;
  final String? title;
  final String? uri;
  final String? name;
  final int? size;
  final String? error;

  Document({
    required this.id,
    required this.text,
    this.title,
    this.uri,
    this.name,
    this.size,
    this.error,
  });

  bool get isPdf => uri != null && uri!.isNotEmpty;
  bool get hasError => error != null && error!.isNotEmpty;
}

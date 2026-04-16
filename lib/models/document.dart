class Document {
  final String id;
  final String text;
  final String? title;

  Document({
    required this.id,
    required this.text,
    this.title,
  });
}

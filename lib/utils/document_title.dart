import '../models/document.dart';

String documentTitle(List<Document> docs, {String fallback = 'Document'}) {
  if (docs.isEmpty) return fallback;
  final doc = docs.first;
  if (doc.name != null && doc.name!.isNotEmpty) return doc.name!;
  final text = doc.text.trim();
  if (text.isEmpty) return fallback;
  final firstLine = text.split('\n').first.trim();
  if (firstLine.isEmpty) return fallback;
  return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
}
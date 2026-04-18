import '../models/document.dart';

String documentTitle(List<Document> docs) {
  if (docs.isEmpty) return 'Document';
  final doc = docs.first;
  if (doc.name != null && doc.name!.isNotEmpty) return doc.name!;
  final text = doc.text.trim();
  if (text.isEmpty) return 'Document';
  final firstLine = text.split('\n').first.trim();
  if (firstLine.isEmpty) return 'Document';
  return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
}
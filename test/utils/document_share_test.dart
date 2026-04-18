import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/main.dart';
import 'package:summsumm/models/document.dart';

void main() {
  group('isDocumentShare', () {
    test('returns false for empty list', () {
      expect(isDocumentShare([]), isFalse);
    });

    test('returns false when all documents are text-only', () {
      final docs = [
        Document(id: '1', text: 'hello world', uri: null),
        Document(id: '2', text: 'another text', uri: null),
      ];
      expect(isDocumentShare(docs), isFalse);
    });

    test('returns true when any document has a URI', () {
      final docs = [
        Document(id: '1', text: '', uri: 'content://com.example/file.pdf', name: 'file.pdf'),
      ];
      expect(isDocumentShare(docs), isTrue);
    });

    test('returns true for mixed text and pdf documents', () {
      final docs = [
        Document(id: '1', text: 'some text', uri: null),
        Document(id: '2', text: '', uri: 'content://com.example/doc.pdf', name: 'doc.pdf'),
      ];
      expect(isDocumentShare(docs), isTrue);
    });
  });
}

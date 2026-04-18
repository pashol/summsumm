import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/document.dart';
import 'package:summsumm/utils/document_title.dart';

void main() {
  group('documentTitle', () {
    test('returns filename when doc has a name', () {
      final doc = Document(id: '1', text: 'some text', name: 'report.pdf');
      expect(documentTitle([doc]), 'report.pdf');
    });

    test('returns first line of text when no name', () {
      final doc = Document(id: '1', text: 'Hello world\nSecond line');
      expect(documentTitle([doc]), 'Hello world');
    });

    test('truncates long first line at 60 chars with ellipsis', () {
      final longLine = 'A' * 70;
      final doc = Document(id: '1', text: longLine);
      final result = documentTitle([doc]);
      expect(result.length, 61); // 60 chars + ellipsis char
      expect(result.endsWith('…'), isTrue);
    });

    test('returns Document when text is empty and no name', () {
      final doc = Document(id: '1', text: '');
      expect(documentTitle([doc]), 'Document');
    });

    test('returns Document for empty list', () {
      expect(documentTitle([]), 'Document');
    });
  });
}
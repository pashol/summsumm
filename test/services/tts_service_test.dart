import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/tts_service.dart';

void main() {
  group('TtsService.stripMarkdown', () {
    test('removes bold markers', () {
      expect(TtsService.stripMarkdown('This is **bold** text'),
          'This is bold text');
    });

    test('removes italic markers', () {
      expect(TtsService.stripMarkdown('This is *italic* text'),
          'This is italic text');
    });

    test('removes headings', () {
      expect(TtsService.stripMarkdown('## Hello'), 'Hello');
    });

    test('removes bullet points', () {
      expect(TtsService.stripMarkdown('- First item'), 'First item');
    });

    test('removes numbered lists', () {
      expect(TtsService.stripMarkdown('1. First item'), 'First item');
    });

    test('removes inline code', () {
      expect(TtsService.stripMarkdown('Use `print()` to output'),
          'Use print() to output');
    });

    test('removes links keeping text', () {
      expect(TtsService.stripMarkdown('[Click here](https://example.com)'),
          'Click here');
    });

    test('removes images keeping alt text', () {
      expect(TtsService.stripMarkdown('![Alt text](image.png)'), 'Alt text');
    });

    test('removes blockquotes', () {
      expect(TtsService.stripMarkdown('> Quoted text'), 'Quoted text');
    });

    test('handles plain text unchanged', () {
      expect(TtsService.stripMarkdown('Just plain text'), 'Just plain text');
    });

    test('removes horizontal rules', () {
      final result = TtsService.stripMarkdown('Above\n---\nBelow');
      expect(result.contains('Above'), isTrue);
      expect(result.contains('Below'), isTrue);
      expect(result.contains('---'), isFalse);
    });

    test('removes fenced code markers keeping content', () {
      expect(
        TtsService.stripMarkdown('```python\nprint("hi")\n```'),
        'print("hi")',
      );
    });
  });
}

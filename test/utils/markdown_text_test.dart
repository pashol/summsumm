import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/utils/markdown_text.dart';

void main() {
  group('markdownWithHardLineBreaks', () {
    test('preserves single newlines as markdown hard breaks', () {
      expect(
        markdownWithHardLineBreaks('First line\nSecond line'),
        'First line  \nSecond line',
      );
    });

    test('preserves blank lines between paragraphs', () {
      expect(
        markdownWithHardLineBreaks('First paragraph\n\nSecond paragraph'),
        'First paragraph\n\nSecond paragraph',
      );
    });
  });
}

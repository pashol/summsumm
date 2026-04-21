import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/summary_style.dart';

void main() {
  group('SummaryStyle', () {
    test('displayName returns correct labels', () {
      expect(SummaryStyle.concise.displayName, 'Concise');
      expect(SummaryStyle.brief.displayName, 'Brief');
      expect(SummaryStyle.detailed.displayName, 'Detailed');
      expect(SummaryStyle.structured.displayName, 'Structured');
    });

    test('forType returns correct styles for meetings', () {
      final styles = SummaryStyle.forType(MeetingType.meeting);
      expect(styles, [SummaryStyle.concise, SummaryStyle.detailed, SummaryStyle.structured]);
      expect(styles, isNot(contains(SummaryStyle.brief)));
    });

    test('forType returns correct styles for documents', () {
      final styles = SummaryStyle.forType(MeetingType.document);
      expect(styles, [SummaryStyle.concise, SummaryStyle.brief, SummaryStyle.detailed]);
      expect(styles, isNot(contains(SummaryStyle.structured)));
    });
  });

  group('langSuffix', () {
    test('returns empty for Same as input', () {
      expect(langSuffix('Same as input', 'Summary'), '');
    });

    test('returns suffix for other languages', () {
      final result = langSuffix('German', 'Summary');
      expect(result, contains('German'));
      expect(result, contains('IMPORTANT'));
    });
  });
}

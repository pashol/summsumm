import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/custom_prompt.dart';

void main() {
  group('CustomPrompt', () {
    test('constructs with required fields', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      expect(prompt.id, 'test-uuid');
      expect(prompt.name, 'Executive Summary');
      expect(prompt.text, 'Summarize this for executives.');
    });

    test('serializes to JSON', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      expect(prompt.toJson(), {
        'id': 'test-uuid',
        'name': 'Executive Summary',
        'text': 'Summarize this for executives.',
      });
    });

    test('deserializes from JSON', () {
      final prompt = CustomPrompt.fromJson({
        'id': 'test-uuid',
        'name': 'Executive Summary',
        'text': 'Summarize this for executives.',
      });
      expect(prompt.id, 'test-uuid');
      expect(prompt.name, 'Executive Summary');
      expect(prompt.text, 'Summarize this for executives.');
    });

    test('copyWith updates fields', () {
      const prompt = CustomPrompt(
        id: 'test-uuid',
        name: 'Executive Summary',
        text: 'Summarize this for executives.',
      );
      final updated = prompt.copyWith(name: 'Updated Name');
      expect(updated.id, 'test-uuid');
      expect(updated.name, 'Updated Name');
      expect(updated.text, 'Summarize this for executives.');
    });
  });
}

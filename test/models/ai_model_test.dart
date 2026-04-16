import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/ai_model.dart';

void main() {
  group('AIModel', () {
    test('displayName appends [Free] for free models', () {
      const model = AIModel(
        id: 'google/gemini-pro:free',
        name: 'Gemini Pro',
        isFree: true,
      );
      expect(model.displayName, 'Gemini Pro [Free]');
    });

    test('displayName does not append for paid models', () {
      const model = AIModel(id: 'openai/gpt-4o', name: 'GPT-4o', isFree: false);
      expect(model.displayName, 'GPT-4o');
    });

    test('fromOpenRouterJson creates model from valid JSON', () {
      final json = {
        'id': 'meta-llama/llama-3-8b:free',
        'name': 'Llama 3 8B',
        'context_length': 8192,
        'pricing': {'prompt': '0.0', 'completion': '0.0'},
        'architecture': {'modality': 'text'},
      };
      final model = AIModel.fromOpenRouterJson(json);
      expect(model.id, 'meta-llama/llama-3-8b:free');
      expect(model.name, 'Llama 3 8B');
      expect(model.isFree, true);
      expect(model.contextLength, 8192);
      expect(model.pricingPrompt, '0.0');
      expect(model.modality, 'text');
    });

    test('fromOpenRouterJson uses id as name fallback', () {
      final json = {'id': 'some-model'};
      final model = AIModel.fromOpenRouterJson(json);
      expect(model.name, 'some-model');
    });

    test('fromOpenRouterJson handles null id', () {
      final model = AIModel.fromOpenRouterJson({});
      expect(model.id, '');
      expect(model.isFree, false);
    });

    test('series extracts provider from id', () {
      const model = AIModel(
          id: 'anthropic/claude-3-haiku', name: 'Claude', isFree: false);
      expect(model.series, 'anthropic');
    });

    test('isTextOnly returns true for text-only modality', () {
      const model = AIModel(
          id: 'test/model', name: 'Test', isFree: false, modality: 'text');
      expect(model.isTextOnly, true);
    });

    test('isTextOnly returns false for multimodal', () {
      const model = AIModel(
          id: 'test/model',
          name: 'Test',
          isFree: false,
          modality: 'text+image');
      expect(model.isTextOnly, false);
    });

    test('contextLabel formats large context', () {
      const model = AIModel(
          id: 'test/model', name: 'Test', isFree: false, contextLength: 128000);
      expect(model.contextLabel, '128K');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('defaults have expected values', () {
      final defaults = AppSettings.defaults();
      expect(defaults.provider, 'openrouter');
      expect(defaults.openrouterModel, '');
      expect(defaults.openaiModel, '');
      expect(defaults.language, 'English');
      expect(defaults.ttsSpeed, 1.0);
    });

    test('copyWith replaces only specified fields', () {
      final original = AppSettings.defaults();
      final updated = original.copyWith(
        openrouterModel: 'google/gemini-2.5-flash',
        ttsSpeed: 1.5,
      );
      expect(updated.openrouterModel, 'google/gemini-2.5-flash');
      expect(updated.ttsSpeed, 1.5);
      expect(updated.language, original.language);
    });

    test('activeModel returns openrouterModel when provider is openrouter', () {
      const settings = AppSettings(
        provider: 'openrouter',
        openrouterModel: 'google/gemini-pro',
        openaiModel: 'gpt-5.4',
        language: 'English',
        ttsSpeed: 1.0,
      );
      expect(settings.activeModel, 'google/gemini-pro');
    });

    test('activeModel returns openaiModel when provider is openai', () {
      const settings = AppSettings(
        provider: 'openai',
        openrouterModel: 'google/gemini-pro',
        openaiModel: 'gpt-5.4',
        language: 'English',
        ttsSpeed: 1.0,
      );
      expect(settings.activeModel, 'gpt-5.4');
    });

    test('toJson/fromJson roundtrip preserves values', () {
      const settings = AppSettings(
        provider: 'openrouter',
        openrouterModel: 'test-model',
        openaiModel: '',
        language: 'German',
        ttsSpeed: 0.8,
      );
      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.provider, settings.provider);
      expect(restored.openrouterModel, settings.openrouterModel);
      expect(restored.openaiModel, settings.openaiModel);
      expect(restored.language, settings.language);
      expect(restored.ttsSpeed, settings.ttsSpeed);
    });

    test('fromJsonString roundtrip', () {
      final settings = AppSettings.defaults();
      final jsonString = settings.toJsonString();
      final restored = AppSettings.fromJsonString(jsonString);
      expect(restored.provider, settings.provider);
      expect(restored.language, settings.language);
    });

    test('fromJson handles missing fields with defaults', () {
      final restored = AppSettings.fromJson({});
      expect(restored.provider, 'openrouter');
      expect(restored.openaiModel, '');
      expect(restored.ttsSpeed, 1.0);
    });
  });

  group('kCuratedModels', () {
    test('contains auto model', () {
      expect(kCuratedModels.any((m) => m.id == 'openrouter/free'), isTrue);
    });

    test('has at least 6 models', () {
      expect(kCuratedModels.length, greaterThanOrEqualTo(6));
    });
  });

  group('kSupportedLanguages', () {
    test('contains English', () {
      expect(kSupportedLanguages, contains('English'));
    });

    test('has at least 10 languages', () {
      expect(kSupportedLanguages.length, greaterThanOrEqualTo(10));
    });
  });

  group('kLanguageTtsCode', () {
    test('maps English to en-US', () {
      expect(kLanguageTtsCode['English'], 'en-US');
    });

    test('has entry for every supported language', () {
      for (final lang in kSupportedLanguages) {
        expect(kLanguageTtsCode, contains(lang));
      }
    });
  });
}

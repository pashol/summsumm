import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/custom_prompt.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/utils/prompt_resolver.dart';

void main() {
  group('PromptResolver', () {
    test('returns hardcoded default for built-in style', () {
      const settings = AppSettings.defaults();
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        settings: settings,
      );
      expect(result, contains('3-5 bullet points'));
    });

    test('returns override when promptOverrides has entry', () {
      final settings = AppSettings.defaults().copyWith(
        promptOverrides: {'concise': 'Custom concise prompt'},
      );
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        settings: settings,
      );
      expect(result, 'Custom concise prompt');
    });

    test('returns custom prompt text when provided', () {
      const settings = AppSettings.defaults();
      const custom = CustomPrompt(
        id: 'uuid',
        name: 'Custom',
        text: 'My custom prompt',
      );
      final result = PromptResolver.resolve(
        customPrompt: custom,
        settings: settings,
      );
      expect(result, 'My custom prompt');
    });

    test('custom prompt takes priority over style override', () {
      final settings = AppSettings.defaults().copyWith(
        promptOverrides: {'concise': 'Override'},
      );
      const custom = CustomPrompt(
        id: 'uuid',
        name: 'Custom',
        text: 'Custom wins',
      );
      final result = PromptResolver.resolve(
        style: SummaryStyle.concise,
        customPrompt: custom,
        settings: settings,
      );
      expect(result, 'Custom wins');
    });
  });
}

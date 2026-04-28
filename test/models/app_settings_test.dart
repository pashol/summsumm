import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';

void main() {
  test('defaults disable local library chat', () {
    const settings = AppSettings.defaults();

    expect(settings.localLibraryChatEnabled, isFalse);
  });

  test('serializes local library chat setting', () {
    const settings = AppSettings.defaults();
    final enabled = settings.copyWith(localLibraryChatEnabled: true);

    final decoded = AppSettings.fromJson(enabled.toJson());

    expect(decoded.localLibraryChatEnabled, isTrue);
  });

  test('missing local library chat setting migrates to disabled', () {
    final decoded = AppSettings.fromJson(const {
      'provider': 'openrouter',
      'openrouterModel': '',
      'openaiModel': '',
      'language': 'Same as input',
      'summaryStyle': 'structured',
      'ttsSpeed': 1.0,
    });

    expect(decoded.localLibraryChatEnabled, isFalse);
  });
}

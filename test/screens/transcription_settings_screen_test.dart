import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/screens/settings/transcription_settings_screen.dart';

class _LoadedSettings extends Settings {
  bool capturedShowExtractedPdfTextOnly = false;

  @override
  AppSettings build() => const AppSettings.defaults();

  @override
  Future<void> setShowExtractedPdfTextOnly(bool enabled) async {
    capturedShowExtractedPdfTextOnly = enabled;
    state = state.copyWith(showExtractedPdfTextOnly: enabled);
  }
}

void main() {
  testWidgets('transcription settings toggles extracted PDF text display',
      (tester) async {
    late _LoadedSettings notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() {
            notifier = _LoadedSettings();
            return notifier;
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TranscriptionSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Show extracted PDF text only'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Show extracted PDF text only'));
    await tester.pumpAndSettle();

    expect(notifier.capturedShowExtractedPdfTextOnly, isTrue);
  });
}

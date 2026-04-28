import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/document.dart';
import 'package:summsumm/models/summary_state.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/providers/summary_provider.dart';
import 'package:summsumm/screens/summary_sheet.dart';

class _DoneSummary extends Summary {
  @override
  SummaryState build() => SummaryState.initial().copyWith(
        status: SummaryStatus.done,
        summary: 'A completed summary.',
      );

  @override
  Future<void> summarize({
    required String inputText,
    required String apiKey,
    required AppSettings settings,
    Document? document,
  }) async {}
}

class _LoadedSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults();

  @override
  Future<void> load() async {}

  @override
  Future<String?> getApiKey(String provider) async => 'test-key';
}

void main() {
  testWidgets('shows follow-up input when summary is done', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          summaryProvider.overrideWith(_DoneSummary.new),
          settingsProvider.overrideWith(_LoadedSettings.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SummarySheet(
              documents: [
                Document(id: 'doc-1', text: 'Text to summarize.'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
  });
}

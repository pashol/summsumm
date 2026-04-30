import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/screens/settings_screen.dart';

class _LoadedSettings extends Settings {
  @override
  AppSettings build() => const AppSettings.defaults();

  @override
  Future<void> load() async {}

  @override
  Future<String?> getApiKey(String provider) async => 'test-key';
}

void main() {
  testWidgets('settings exposes app info through About', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'summsumm',
      packageName: 'app.summsumm',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_LoadedSettings.new)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );

    final aboutRow = find.widgetWithText(ListTile, 'About');

    await tester.scrollUntilVisible(aboutRow, 500);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(aboutRow, findsOneWidget);

    await tester.tap(aboutRow);
    await tester.pumpAndSettle();

    expect(find.text('AI Text Summarizer'), findsOneWidget);
    expect(find.text('Version 1.2.3  (4)'), findsOneWidget);
  });
}

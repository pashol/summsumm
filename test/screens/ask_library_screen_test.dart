import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/screens/ask_library_screen.dart';

void main() {
  testWidgets('shows Ask Library title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AskLibraryScreen(),
        ),
      ),
    );

    expect(find.text('Ask Library'), findsOneWidget);
  });
}

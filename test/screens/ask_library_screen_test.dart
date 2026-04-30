import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/ask_library_chat_provider.dart';
import 'package:summsumm/providers/library_rag_provider.dart';
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

  testWidgets('new chat action clears the current Ask Library chat',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibraryChatProvider.overrideWith(
            (ref) => TestAskLibraryChatNotifier(
              ref,
              const AskLibraryChatState(
                messages: [
                  AskLibraryMessage(
                    role: 'user',
                    content: 'What did I record?',
                  ),
                  AskLibraryMessage(
                    role: 'assistant',
                    content: 'A project update.',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AskLibraryScreen(),
        ),
      ),
    );

    expect(find.text('What did I record?'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);

    await tester.tap(find.byTooltip('New chat'));
    await tester.pump();

    expect(find.text('What did I record?'), findsNothing);
    expect(find.text('A project update.'), findsNothing);
  });

  testWidgets('assistant messages render as markdown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibraryChatProvider.overrideWith(
            (ref) => TestAskLibraryChatNotifier(
              ref,
              const AskLibraryChatState(
                messages: [
                  AskLibraryMessage(role: 'user', content: 'Summarize this'),
                  AskLibraryMessage(
                    role: 'assistant',
                    content: '## Result\n\n- First point\n- Second point',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AskLibraryScreen(),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}

class FakeLibraryRagSetupNotifier extends LibraryRagSetupNotifier {
  @override
  LibraryRagSetupState build() {
    return const LibraryRagSetupState(readiness: LibraryRagReadiness.ready);
  }

  @override
  Future<void> refreshReadiness() async {}
}

class TestAskLibraryChatNotifier extends AskLibraryChatNotifier {
  TestAskLibraryChatNotifier(super.ref, AskLibraryChatState initialState) {
    state = initialState;
  }
}

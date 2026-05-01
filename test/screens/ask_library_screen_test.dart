import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/chat_message.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/ask_library_chat_provider.dart';
import 'package:summsumm/providers/ask_library_session_provider.dart';
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

  testWidgets('new chat action clears the current Ask Library chat', (
    tester,
  ) async {
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

  testWidgets('new assistant answers scroll into view automatically', (
    tester,
  ) async {
    late TestAskLibraryChatNotifier notifier;
    final initialMessages = List<AskLibraryMessage>.generate(
      12,
      (index) => AskLibraryMessage(
        role: index.isEven ? 'user' : 'assistant',
        content: 'Message $index',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibraryChatProvider.overrideWith((ref) {
            notifier = TestAskLibraryChatNotifier(
              ref,
              AskLibraryChatState(messages: initialMessages),
            );
            return notifier;
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(400, 300)),
            child: AskLibraryScreen(),
          ),
        ),
      ),
    );

    expect(find.text('Newest answer'), findsNothing);

    notifier.setChatState(
      AskLibraryChatState(
        messages: [
          ...initialMessages,
          const AskLibraryMessage(role: 'user', content: 'Newest question'),
          const AskLibraryMessage(
            role: 'assistant',
            content: 'Newest answer',
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Newest answer'), findsOneWidget);
  });

  testWidgets('saved assistant messages render citation chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibrarySessionProvider.overrideWith(
            (ref) => TestAskLibrarySessionNotifier(
              AskLibrarySessionState(
                messages: [
                  const ChatMessage(role: 'user', content: 'What happened?'),
                  const ChatMessage(
                    role: 'assistant',
                    content: 'The budget was approved.',
                    metadata: {
                      'citations': [
                        {
                          'libraryItemId': 'meeting-1',
                          'title': 'Budget Meeting',
                          'sourceKind': 'meeting',
                          'contentType': 'transcript',
                        },
                      ],
                    },
                  ),
                ],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
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

    expect(find.text('Budget Meeting'), findsOneWidget);
  });

  testWidgets('saved sessions do not append stale in-memory chat replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibrarySessionProvider.overrideWith(
            (ref) => TestAskLibrarySessionNotifier(
              AskLibrarySessionState(
                messages: const [
                  ChatMessage(role: 'user', content: 'Saved question'),
                  ChatMessage(role: 'assistant', content: 'Saved answer'),
                ],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
          askLibraryChatProvider.overrideWith(
            (ref) => TestAskLibraryChatNotifier(
              ref,
              const AskLibraryChatState(
                messages: [
                  AskLibraryMessage(role: 'user', content: 'Old question'),
                  AskLibraryMessage(role: 'assistant', content: 'Old answer'),
                  AskLibraryMessage(role: 'user', content: 'Another question'),
                  AskLibraryMessage(role: 'assistant', content: 'Duplicate answer'),
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

    expect(find.text('Saved question'), findsOneWidget);
    expect(find.text('Saved answer'), findsOneWidget);
    expect(find.text('Duplicate answer'), findsNothing);
  });

  testWidgets('drawer new chat clears the active chat', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRagSetupProvider.overrideWith(FakeLibraryRagSetupNotifier.new),
          askLibraryChatProvider.overrideWith(
            (ref) => TestAskLibraryChatNotifier(
              ref,
              const AskLibraryChatState(
                messages: [
                  AskLibraryMessage(role: 'user', content: 'Old question'),
                  AskLibraryMessage(role: 'assistant', content: 'Old answer'),
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

    expect(find.text('Old question'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Old question'), findsNothing);
    expect(find.text('Old answer'), findsNothing);
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

  void setChatState(AskLibraryChatState next) {
    state = next;
  }
}

class TestAskLibrarySessionNotifier extends AskLibrarySessionNotifier {
  TestAskLibrarySessionNotifier(AskLibrarySessionState initialState)
    : super(_FakeRef()) {
    state = initialState;
  }
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

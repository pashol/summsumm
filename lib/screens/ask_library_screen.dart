import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/library_rag.dart';
import '../providers/ask_library_chat_provider.dart';
import '../providers/ask_library_session_provider.dart';
import '../providers/library_rag_provider.dart';
import '../utils/markdown_text.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/spring_page_route.dart';
import 'meeting_detail_screen.dart';

class AskLibraryScreen extends ConsumerStatefulWidget {
  const AskLibraryScreen({super.key});

  @override
  ConsumerState<AskLibraryScreen> createState() => _AskLibraryScreenState();
}

class _AskLibraryScreenState extends ConsumerState<AskLibraryScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryRagSetupProvider.notifier).refreshReadiness();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(libraryRagSetupProvider);
    final chat = ref.watch(askLibraryChatProvider);
    final session = ref.watch(askLibrarySessionProvider);

    ref.listen<AskLibraryChatState>(askLibraryChatProvider, (previous, next) {
      final previousMessages = previous?.messages ?? const <AskLibraryMessage>[];
      final messageCountIncreased = next.messages.length > previousMessages.length;
      final lastAssistantChanged =
          next.isStreaming &&
          next.messages.isNotEmpty &&
          previousMessages.isNotEmpty &&
          next.messages.last.role == 'assistant' &&
          previousMessages.last.role == 'assistant' &&
          next.messages.last.content != previousMessages.last.content;

      if (messageCountIncreased || lastAssistantChanged) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(AppLocalizations.of(context)!.askLibraryTitle),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: () {
                ref
                    .read(askLibrarySessionProvider.notifier)
                    .saveCurrentSession();
                ref.read(askLibrarySessionProvider.notifier).newSession();
                _newChat();
              },
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      drawer: const ChatHistoryDrawer(),
      body: switch (setup.readiness) {
        LibraryRagReadiness.disabled => _SetupView(
          text:
              'Enable local library chat to index your transcripts and documents for contextual search.',
          buttonText: 'Enable',
          onPressed: () =>
              ref.read(libraryRagSetupProvider.notifier).enableAndEstimate(),
        ),
        LibraryRagReadiness.enabledNotIndexed => _EstimateView(setup: setup),
        LibraryRagReadiness.indexing => _IndexingView(setup: setup),
        LibraryRagReadiness.failed => _SetupView(
          text: setup.error ?? 'Local library chat failed.',
          buttonText: 'Retry',
          onPressed: () =>
              ref.read(libraryRagSetupProvider.notifier).loadEstimate(),
        ),
        LibraryRagReadiness.ready || LibraryRagReadiness.stale => _ChatView(
          chat: chat,
          session: session,
          controller: _controller,
          scrollController: _scrollController,
          isStale: setup.readiness == LibraryRagReadiness.stale,
          staleError: setup.error,
          onUpdateIndex: () =>
              ref.read(libraryRagSetupProvider.notifier).updateIndex(),
          onSend: _send,
          onCitationTap: _openCitation,
        ),
      },
    );
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    ref.read(askLibraryChatProvider.notifier).sendMessage(text);
  }

  void _newChat() {
    _controller.clear();
    ref.read(askLibraryChatProvider.notifier).newChat();
  }

  void _openCitation(LibraryCitation citation) {
    Navigator.push<void>(
      context,
      SpringPageRoute(
        builder: (_) => MeetingDetailScreen(
          meetingId: citation.libraryItemId,
          initialTabIndex: citation.contentType == LibraryContentType.transcript
              ? 1
              : 0,
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  const _SetupView({
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}

class _EstimateView extends ConsumerWidget {
  final LibraryRagSetupState setup;

  const _EstimateView({required this.setup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = setup.estimate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              estimate == null
                  ? 'Preparing index estimate...'
                  : 'Index ${estimate.meetingCount} meetings and ${estimate.documentCount} documents. Estimated chunks: ${estimate.estimatedChunks}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: estimate?.hasEligibleContent == true
                  ? () => ref
                        .read(libraryRagSetupProvider.notifier)
                        .indexLibrary()
                  : null,
              child: const Text('Start indexing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexingView extends StatelessWidget {
  final LibraryRagSetupState setup;

  const _IndexingView({required this.setup});

  @override
  Widget build(BuildContext context) {
    final progress = setup.progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress?.fraction),
            const SizedBox(height: 16),
            Text(progress?.currentTitle ?? 'Indexing library...'),
          ],
        ),
      ),
    );
  }
}

class _DisplayMessage {
  final String role;
  final String content;
  final List<LibraryCitation> citations;

  const _DisplayMessage({
    required this.role,
    required this.content,
    this.citations = const [],
  });
}

class _ChatView extends StatelessWidget {
  final AskLibraryChatState chat;
  final AskLibrarySessionState session;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isStale;
  final String? staleError;
  final VoidCallback onUpdateIndex;
  final VoidCallback onSend;
  final ValueChanged<LibraryCitation> onCitationTap;

  const _ChatView({
    required this.chat,
    required this.session,
    required this.controller,
    required this.scrollController,
    required this.isStale,
    required this.staleError,
    required this.onUpdateIndex,
    required this.onSend,
    required this.onCitationTap,
  });

  List<_DisplayMessage> _buildMessages() {
    final messages = <_DisplayMessage>[];

    // Add all session messages
    for (final msg in session.messages) {
      messages.add(
        _DisplayMessage(
          role: msg.role,
          content: msg.content,
          citations: _citationsFromMetadata(msg.metadata),
        ),
      );
    }

    // During streaming, chat may have messages not yet persisted to session.
    // Append any extra chat messages beyond what session has.
    if ((chat.isStreaming || session.messages.isEmpty) &&
        chat.messages.length > session.messages.length) {
      final extras = chat.messages.sublist(session.messages.length);
      for (final msg in extras) {
        messages.add(
          _DisplayMessage(
            role: msg.role,
            content: msg.content,
            citations: msg.citations,
          ),
        );
      }
    }

    return messages;
  }

  List<LibraryCitation> _citationsFromMetadata(Map<String, dynamic>? metadata) {
    final rawCitations = metadata?['citations'];
    if (rawCitations is! List) return const [];

    return rawCitations
        .whereType<Map<String, dynamic>>()
        .map((citation) => LibraryCitation.fromJson(citation))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayMessages = _buildMessages();
    return Column(
      children: [
        if (isStale)
          MaterialBanner(
            content: Text(
              staleError == null
                  ? l10n.askLibraryStaleBanner
                  : l10n.askLibraryStaleBannerError,
            ),
            actions: [
              TextButton(
                onPressed: onUpdateIndex,
                child: Text(l10n.askLibraryUpdateIndexButton),
              ),
            ],
          ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: displayMessages.length,
            itemBuilder: (context, index) {
              final message = displayMessages[index];
              final isUser = message.role == 'user';
              final colorScheme = Theme.of(context).colorScheme;
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  color: isUser
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        message.role == 'assistant'
                            ? MarkdownBody(
                                data: markdownWithHardLineBreaks(
                                  message.content,
                                ),
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Text(
                                message.content,
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                        if (message.citations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: message.citations.map((citation) {
                              return ActionChip(
                                label: Text(citation.title),
                                onPressed: () => onCitationTap(citation),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (chat.error != null)
          Text(
            chat.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your library...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: chat.isStreaming ? null : (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: chat.isStreaming ? null : onSend,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

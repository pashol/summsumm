import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/library_rag.dart';
import '../providers/ask_library_chat_provider.dart';
import '../providers/library_rag_provider.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.askLibraryTitle),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: _newChat,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
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
          initialTabIndex:
              citation.contentType == LibraryContentType.transcript ? 1 : 0,
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  const _SetupView(
      {required this.text, required this.buttonText, required this.onPressed});

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
                  ? () =>
                      ref.read(libraryRagSetupProvider.notifier).indexLibrary()
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

class _ChatView extends StatelessWidget {
  final AskLibraryChatState chat;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isStale;
  final String? staleError;
  final VoidCallback onUpdateIndex;
  final VoidCallback onSend;
  final ValueChanged<LibraryCitation> onCitationTap;

  const _ChatView({
    required this.chat,
    required this.controller,
    required this.scrollController,
    required this.isStale,
    required this.staleError,
    required this.onUpdateIndex,
    required this.onSend,
    required this.onCitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            itemCount: chat.messages.length,
            itemBuilder: (context, index) {
              final message = chat.messages[index];
              return Align(
                alignment: message.role == 'user'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.content),
                        if (message.citations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: message.citations
                                .map(
                                  (citation) => ActionChip(
                                    label: Text(citation.title),
                                    onPressed: () => onCitationTap(citation),
                                  ),
                                )
                                .toList(),
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
          Text(chat.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

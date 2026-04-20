import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/providers/meeting_chat_provider.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/widgets/meeting_share_sheet.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen>
    with TickerProviderStateMixin {
  bool _diarize = false;
  late final TabController _tabController;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meetingLibraryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meeting = ref.watch(meetingProvider(widget.meetingId));
    final provider = ref.watch(meetingProvider(widget.meetingId).notifier);
    ref.listen(meetingChatProvider(widget.meetingId), (_, __) {
      _scrollChatToBottom();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(meeting.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => showMeetingShareSheet(context, meeting),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _renameMeeting(context, meeting.title, provider),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteMeeting(context, meeting, provider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _buildMetadata(meeting),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Transcript'),
              Tab(text: 'Chat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(meeting, provider),
                _buildTranscriptTab(meeting, provider),
                _buildChatTab(meeting),
              ],
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildMetadata(Meeting meeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meeting.type == MeetingType.meeting)
          Text('Duration: ${_formatDuration(meeting.durationSec)}'),
        Text('Recorded: ${_formatDateTime(context, meeting.createdAt)}'),
        if (meeting.provider != null) Text('Transcribed by: ${meeting.provider}'),
        if (meeting.lastError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 18,),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meeting.lastError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13,),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryTab(Meeting meeting, MeetingNotifier provider) {
    Widget content;
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          content = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => provider.summarize(),
                child: const Text('Summarize'),
              ),
            ),
          );
        } else {
          content = const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No transcript yet.\nGo to the Transcript tab to transcribe.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      case MeetingStatus.transcribing:
        content = const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Transcribing…'),
            ],
          ),
        );
      case MeetingStatus.transcribed:
        content = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: provider.summarize,
              child: const Text('Summarize'),
            ),
          ),
        );
      case MeetingStatus.summarizing:
        content = const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Summarizing…'),
            ],
          ),
        );
      case MeetingStatus.done:
        content = SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(data: meeting.summary ?? ''),
        );
      case MeetingStatus.failed:
        content = const SizedBox.shrink();
    }
    return content;
  }

  Widget _buildTranscriptTab(Meeting meeting, MeetingNotifier provider) {
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'This is a document, not a recording.\nGo to the Summary tab to process it.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final settings = ref.watch(settingsProvider);
        final isOpenRouter = settings.provider == 'openrouter';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: isOpenRouter ? '' : 'Diarization requires OpenRouter',
                child: Row(
                  children: [
                    Switch(
                      value: _diarize,
                      onChanged: isOpenRouter
                          ? (v) => setState(() => _diarize = v)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Diarize speakers',
                      style: TextStyle(
                        color:
                            isOpenRouter ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => provider.transcribe(diarize: _diarize),
                child: const Text('Transcribe'),
              ),
            ],
          ),
        );
      case MeetingStatus.transcribing:
        return _TranscribingIndicator(status: meeting.transcriptionStatus);
      case MeetingStatus.transcribed:
      case MeetingStatus.summarizing:
      case MeetingStatus.done:
        return Column(
          children: [
            if (meeting.type == MeetingType.document)
              MaterialBanner(
                content: const Text('This is the imported document content, not a transcript.'),
                actions: [const SizedBox.shrink()],
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(meeting.transcript ?? ''),
              ),
            ),
          ],
        );
      case MeetingStatus.failed:
        if (meeting.type == MeetingType.document) return const SizedBox.shrink();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: provider.retry,
              child: const Text('Retry'),
            ),
          ),
        );
    }
  }

  Widget _buildChatTab(Meeting meeting) {
    if (meeting.transcript == null) {
      final isDocument = meeting.type == MeetingType.document;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isDocument
                ? 'Document content not available yet.\nGo to the Summary tab to process it.'
                : 'Transcribe the meeting first to start chatting.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final meetingId = meeting.id;
    final chatState = ref.watch(meetingChatProvider(meetingId));
    final chatNotifier = ref.read(meetingChatProvider(meetingId).notifier);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: chatState.messages.length,
            itemBuilder: (context, index) {
              final msg = chatState.messages[index];
              final isUser = msg.role == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8,),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg.content),
                ),
              );
            },
          ),
        ),
        if (chatState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              chatState.error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12,),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about this meeting…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: chatState.isStreaming
                        ? null
                        : (_) => _sendChatMessage(meeting, chatNotifier),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: chatState.isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2,),)
                      : const Icon(Icons.send),
                  onPressed: chatState.isStreaming
                      ? null
                      : () => _sendChatMessage(meeting, chatNotifier),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _sendChatMessage(Meeting meeting, MeetingChatNotifier notifier) {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    _chatInputController.clear();
    notifier.sendMessage(
      text,
      transcript: meeting.transcript!,
      summary: meeting.summary,
    );
  }

   String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

   String _formatDateTime(BuildContext context, DateTime dateTime) {
    // Get the system locale and format accordingly
    final locale = Localizations.localeOf(context);
    return DateFormat.yMMMd(locale.languageCode).add_jm().format(dateTime.toLocal());
  }

  void _renameMeeting(BuildContext context, String initialTitle, MeetingNotifier provider) {
    final controller = TextEditingController(text: initialTitle);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Meeting'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.rename(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMeeting(BuildContext context, Meeting meeting, MeetingNotifier provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meeting.type == MeetingType.document
            ? 'Delete Document?'
            : 'Delete Meeting?',),
        content: Text(meeting.type == MeetingType.document
            ? 'This will permanently delete this document summary.'
            : 'This will permanently delete the recording and all data.',),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.delete();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TranscribingIndicator extends StatefulWidget {
  final String? status;
  const _TranscribingIndicator({this.status});

  @override
  State<_TranscribingIndicator> createState() => _TranscribingIndicatorState();
}

class _TranscribingIndicatorState extends State<_TranscribingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _wordIndex = 0;

  static const _words = ['Preparing', 'Analyzing', 'Preprocessing', 'Transcribing', 'Finalizing'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _wordIndex = (_wordIndex + 1) % _words.length);
          _controller.forward(from: 0);
        }
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _TranscribingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.status;
    if (status != null) {
      final idx = _words.indexWhere((w) => w == status);
      if (idx >= 0) _wordIndex = idx;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final word = widget.status ?? _words[_wordIndex];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              word,
              key: ValueKey(word),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

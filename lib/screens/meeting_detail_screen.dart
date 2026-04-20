import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/models/app_settings.dart';
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
  SummaryStyle? _selectedStyle;
  String? _selectedLanguage;
  bool _showAddControls = false;
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
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => provider.summarize(),
                child: const Text('Summarize'),
              ),
            ),
          );
        } else {
          return const Center(
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
        return const Center(
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () => provider.summarize(),
              child: const Text('Summarize'),
            ),
          ),
        );
      case MeetingStatus.summarizing:
        return _buildSummarizingContent(meeting);
      case MeetingStatus.done:
        return _buildDoneContent(meeting, provider);
      case MeetingStatus.failed:
        return _buildFailedContent(meeting, provider);
    }
  }

  Widget _buildSummarizingContent(Meeting meeting) {
    final currentSummary = meeting.summaries.lastOrNull;
    final content = currentSummary?.content ?? '';

    if (content.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Summarizing…'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (meeting.summaries.length > 1)
          _buildChipRow(meeting, null),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'Summarizing…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MarkdownBody(data: content),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneContent(Meeting meeting, MeetingNotifier provider) {
    return Column(
      children: [
        _buildChipRow(meeting, provider),
        if (_showAddControls) _buildAddControls(meeting, provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(data: meeting.summary ?? ''),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedContent(Meeting meeting, MeetingNotifier provider) {
    if (meeting.summaries.isNotEmpty) {
      return Column(
        children: [
          _buildChipRow(meeting, provider),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meeting.lastError ?? 'An error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: provider.retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
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

  Widget _buildChipRow(Meeting meeting, MeetingNotifier? provider) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: meeting.summaries.length + 1,
        itemBuilder: (context, index) {
          if (index == meeting.summaries.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: const Icon(Icons.add, size: 18),
                selected: _showAddControls,
                onSelected: (_) => setState(() => _showAddControls = !_showAddControls),
              ),
            );
          }

          final summary = meeting.summaries[index];
          final styleCount = meeting.summaries.where((s) => s.style == summary.style).toList();
          final styleIndex = styleCount.indexOf(summary);
          final chipLabel = styleCount.length > 1
              ? '${summary.style.displayName} ${styleIndex + 1}'
              : summary.style.displayName;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(chipLabel),
              selected: summary == meeting.summaries.first,
              onSelected: (_) {},
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddControls(Meeting meeting, MeetingNotifier provider) {
    final availableStyles = SummaryStyle.forType(meeting.type);

    _selectedStyle ??= _resolveInitialStyle(ref.read(settingsProvider).summaryStyle, meeting.type);
    _selectedLanguage ??= ref.read(settingsProvider).language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<SummaryStyle>(
            value: _selectedStyle,
            decoration: const InputDecoration(
              labelText: 'Style',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: availableStyles
                .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedStyle = v);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: kSupportedLanguages
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedLanguage = v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final style = _selectedStyle!;
                    final language = _selectedLanguage!;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Generate Summary'),
                        content: Text('Generate a new summary in $language with $style style?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _showAddControls = false;
                                _selectedStyle = null;
                                _selectedLanguage = null;
                              });
                              provider.summarize(style: style, language: language);
                            },
                            child: const Text('Generate'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Summarize'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _showAddControls = false;
                  _selectedStyle = null;
                  _selectedLanguage = null;
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SummaryStyle _resolveInitialStyle(String settingsStyle, MeetingType type) {
    final parsed = SummaryStyle.values.firstWhere(
      (s) => s.name == settingsStyle,
      orElse: () => SummaryStyle.structured,
    );
    final available = SummaryStyle.forType(type);
    if (available.contains(parsed)) return parsed;
    return available.first;
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
        return _TranscribingIndicator(
          status: meeting.transcriptionStatus,
          progress: meeting.transcriptionProgress,
        );
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
  final double? progress;
  const _TranscribingIndicator({this.status, this.progress});

  @override
  State<_TranscribingIndicator> createState() => _TranscribingIndicatorState();
}

class _TranscribingIndicatorState extends State<_TranscribingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayStatus = widget.status ?? 'Preparing…';
    final determinate = widget.progress != null;
    final progress = widget.progress ?? 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulseController.drive(Tween(begin: 0.5, end: 1.0)),
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                displayStatus,
                key: ValueKey(displayStatus),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: determinate ? progress : null,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            if (determinate) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/models/summary_style.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/providers/meeting_chat_provider.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/meeting_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/utils/localized_strings.dart';
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
  int _activeSummaryIndex = 0;
  late final TabController _tabController;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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
    final l10n = AppLocalizations.of(context)!;
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
            tooltip: l10n.libraryShare,
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
            child: _buildMetadata(meeting, l10n),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.meetingDetailTabSummary),
              Tab(text: l10n.meetingDetailTabTranscript),
              Tab(text: l10n.meetingDetailTabChat),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(meeting, provider, l10n),
                _buildTranscriptTab(meeting, provider, l10n),
                _buildChatTab(meeting, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(Meeting meeting, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meeting.type == MeetingType.meeting)
              _MetadataRow(
                icon: Icons.timer_outlined,
                label: l10n.meetingDetailDuration,
                value: _formatDuration(meeting.durationSec),
              ),
            _MetadataRow(
              icon: Icons.calendar_today,
              label: l10n.meetingDetailRecorded,
              value: _formatDateTime(context, meeting.createdAt),
            ),
            if (meeting.provider != null)
              _MetadataRow(
                icon: Icons.transcribe,
                label: l10n.meetingDetailTranscribedBy,
                value: meeting.provider!,
              ),
            if (meeting.lastError != null) ...[
              const SizedBox(height: 8),
              MaterialBanner(
                content: Text(meeting.lastError!),
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.errorContainer,
                actions: const [SizedBox.shrink()],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(Meeting meeting, MeetingNotifier provider, AppLocalizations l10n) {
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () => provider.summarize(),
                child: Text(l10n.summarizeButton),
              ),
            ),
          );
        } else {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.meetingDetailNoTranscript,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      case MeetingStatus.transcribing:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.meetingDetailTranscribing),
            ],
          ),
        );
      case MeetingStatus.transcribed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () => provider.summarize(),
              child: Text(l10n.summarizeButton),
            ),
          ),
        );
      case MeetingStatus.summarizing:
        return _buildSummarizingContent(meeting, l10n);
      case MeetingStatus.done:
        return _buildDoneContent(meeting, provider);
      case MeetingStatus.failed:
        return _buildFailedContent(meeting, provider, l10n);
    }
  }

  Widget _buildSummarizingContent(Meeting meeting, AppLocalizations l10n) {
    final currentSummary = meeting.summaries.lastOrNull;
    final content = currentSummary?.content ?? '';

    if (content.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.meetingDetailSummarizing),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (meeting.summaries.length > 1) _buildChipRow(meeting, null, l10n),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.meetingDetailSummarizing,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            thumbVisibility: _isDesktop,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MarkdownBody(data: content),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneContent(Meeting meeting, MeetingNotifier provider) {
    final activeContent = meeting.summaries.isNotEmpty
        ? meeting.summaries[_activeSummaryIndex].content
        : '';
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildChipRow(meeting, provider, l10n),
        if (_showAddControls) _buildAddControls(meeting, provider, l10n),
        Expanded(
          child: Scrollbar(
            thumbVisibility: _isDesktop,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(data: activeContent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedContent(Meeting meeting, MeetingNotifier provider, AppLocalizations l10n) {
    if (meeting.summaries.isNotEmpty) {
      return Column(
        children: [
          _buildChipRow(meeting, provider, l10n),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.9 + (0.1 * value),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Text(
                        meeting.lastError ?? l10n.meetingDetailErrorOccurred,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: provider.retry,
                      child: Text(l10n.retryButton),
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
        child: FilledButton(
          onPressed: provider.retry,
          child: Text(l10n.retryButton),
        ),
      ),
    );
  }

  Widget _buildChipRow(Meeting meeting, MeetingNotifier? provider, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ...List.generate(meeting.summaries.length, (index) {
            final summary = meeting.summaries[index];
            final styleCount = meeting.summaries
                .where((s) => s.style == summary.style)
                .toList();
            final styleIndex = styleCount.indexOf(summary);
            final styleTitle = summary.style.localizedTitle(context);
            final chipLabel = styleCount.length > 1
                ? '$styleTitle ${styleIndex + 1}'
                : styleTitle;

            return ChoiceChip(
              label: Text(chipLabel),
              selected: index == _activeSummaryIndex,
              onSelected: (_) {
                HapticFeedback.lightImpact();
                setState(() => _activeSummaryIndex = index);
              },
            );
          }),
          ChoiceChip(
            label: const Icon(Icons.add, size: 18),
            selected: _showAddControls,
            onSelected: (_) {
                HapticFeedback.lightImpact();
                setState(() => _showAddControls = !_showAddControls);
              },
          ),
        ],
      ),
    );
  }

  Widget _buildAddControls(Meeting meeting, MeetingNotifier provider, AppLocalizations l10n) {
    final availableStyles = SummaryStyle.forType(meeting.type);

    _selectedStyle ??= _resolveInitialStyle(
      ref.read(settingsProvider).summaryStyle,
      meeting.type,
    );
    _selectedLanguage ??= ref.read(settingsProvider).language;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<SummaryStyle>(
            initialValue: _selectedStyle,
            decoration: InputDecoration(
              labelText: l10n.settingsStyleLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: availableStyles
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.localizedTitle(context))),)
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedStyle = v);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedLanguage,
            decoration: InputDecoration(
              labelText: l10n.settingsLanguageLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: kSupportedLanguages
                .map((l) => DropdownMenuItem(value: l, child: Text(localizedLanguageName(context, l))))
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
                    final styleTitle = style.localizedTitle(context);
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.meetingDetailGenerateSummary),
                        content: Text(
                          l10n.meetingDetailGenerateConfirm(language, styleTitle),
                        ),
                        actions: _buildDialogActions(ctx, [
                          (label: l10n.cancelButton, onPressed: () => Navigator.pop(ctx), isDefault: false),
                          (label: l10n.meetingDetailGenerate, onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _showAddControls = false;
                                _selectedStyle = null;
                                _selectedLanguage = null;
                              });
                              provider.summarize(
                                style: style,
                                language: language,
                              );
                            }, isDefault: true),
                        ]),
                      ),
                    );
                  },
                  child: Text(l10n.summarizeButton),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _showAddControls = false;
                  _selectedStyle = null;
                  _selectedLanguage = null;
                }),
                child: Text(l10n.cancelButton),
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

  Widget _buildTranscriptTab(Meeting meeting, MeetingNotifier provider, AppLocalizations l10n) {
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.meetingDetailNotRecording,
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
                message: isOpenRouter ? '' : l10n.meetingDetailDiarizationRequires,
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
                      l10n.meetingDetailDiarizeSpeakers,
                      style: TextStyle(
                        color: isOpenRouter
                            ? null
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => provider.transcribe(diarize: _diarize),
                child: Text(l10n.transcribeButton),
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
                content: Text(l10n.meetingDetailDocumentContent),
                actions: const [SizedBox.shrink()],
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            Expanded(
              child: Scrollbar(
                thumbVisibility: _isDesktop,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(data: meeting.transcript ?? ''),
                ),
              ),
            ),
          ],
        );
      case MeetingStatus.failed:
        if (meeting.type == MeetingType.document) return const SizedBox.shrink();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: provider.retry,
              child: Text(l10n.retryButton),
            ),
          ),
        );
    }
  }

  Widget _buildChatTab(Meeting meeting, AppLocalizations l10n) {
    final isDocument = meeting.type == MeetingType.document;
    if (!isDocument && meeting.transcript == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.meetingDetailTranscribeFirst,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (isDocument && meeting.audioPath.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.meetingDetailDocumentNotReady,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final meetingId = meeting.id;
    final chatState = ref.watch(meetingChatProvider(meetingId));
    final chatNotifier =
        ref.read(meetingChatProvider(meetingId).notifier);

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: _isDesktop,
            controller: _chatScrollController,
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final msg = chatState.messages[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Opacity(
                        opacity: scale,
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                        ),
                      ),
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isUser
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (chatState.error != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              chatState.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
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
                    decoration: InputDecoration(
                      hintText: l10n.meetingDetailChatHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: chatState.isStreaming
                        ? null
                        : (_) =>
                            _sendChatMessage(meeting, chatNotifier),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: chatState.isStreaming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
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
    if (meeting.type == MeetingType.document) {
      notifier.sendDocumentMessage(text, audioPath: meeting.audioPath);
    } else {
      notifier.sendMessage(
        text,
        transcript: meeting.transcript!,
        summary: meeting.summary,
      );
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context);
    return DateFormat.yMMMd(locale.languageCode)
        .add_jm()
        .format(dateTime.toLocal());
  }

  void _renameMeeting(
    BuildContext context,
    String initialTitle,
    MeetingNotifier provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialTitle);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryRenameMeeting),
        content: TextField(controller: controller),
        actions: _buildDialogActions(ctx, [
          DialogAction(
            label: l10n.cancelButton,
            onPressed: () => Navigator.pop(ctx),
            isDefault: false,
          ),
          DialogAction(
            label: l10n.saveButton,
            onPressed: () {
              provider.rename(controller.text);
              Navigator.pop(ctx);
            },
            isDefault: true,
          ),
        ]),
      ),
    );
  }

  void _deleteMeeting(
    BuildContext context,
    Meeting meeting,
    MeetingNotifier provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          meeting.type == MeetingType.document
              ? l10n.libraryDeleteDocument
              : l10n.libraryDeleteMeeting,
        ),
        content: Text(
          meeting.type == MeetingType.document
              ? l10n.libraryDeleteDocumentConfirm
              : l10n.libraryDeleteMeetingConfirm,
        ),
        actions: _buildDialogActions(ctx, [
          DialogAction(
            label: l10n.cancelButton,
            onPressed: () => Navigator.pop(ctx),
            isDefault: false,
          ),
          DialogAction(
            label: l10n.deleteButton,
            onPressed: () {
              provider.delete();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            isDefault: true,
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildDialogActions(
    BuildContext context,
    List<({String label, VoidCallback onPressed, bool isDefault})> actions,
  ) {
    final ordered =
        Platform.isWindows ? actions.reversed.toList() : actions;
    return ordered.map((action) {
      if (action.isDefault) {
        return FilledButton(
          onPressed: action.onPressed,
          child: Text(action.label),
        );
      }
      return TextButton(
        onPressed: action.onPressed,
        child: Text(action.label),
      );
    }).toList();
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
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
  State<_TranscribingIndicator> createState() =>
      _TranscribingIndicatorState();
}

class _TranscribingIndicatorState extends State<_TranscribingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
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
            ScaleTransition(
              scale: _breathAnimation,
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.primary,
                ),
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

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/document.dart';
import '../models/summary_state.dart';
import '../providers/settings_provider.dart';
import '../providers/summary_provider.dart';
import 'package:summsumm/providers/voice_service_provider.dart';
import '../widgets/document_carousel.dart';
import '../widgets/glass_card.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import '../theme/reduced_motion.dart';
import '../theme/m3_tokens.dart';
import 'settings_screen.dart';

class SummarySheet extends ConsumerStatefulWidget {
  final List<Document> documents;
  final int initialIndex;
  final void Function(String summary)? onSummarized;
  final void Function(String error)? onSummaryFailed;
  final ScrollController? scrollController; // when set, skip inner DraggableScrollableSheet
  final VoidCallback? onClose; // when set, overrides Navigator.pop()

  const SummarySheet({
    super.key,
    required this.documents,
    this.initialIndex = 0,
    this.onSummarized,
    this.onSummaryFailed,
    this.scrollController,
    this.onClose,
  });

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  ScrollController? _scrollCtrl;

   void _startRecording(LongPressStartDetails _) async {
    try {
      setState(() => _isRecording = true);
      await ref.read(voiceServiceProvider).startRecording();
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.summarySheetFailedRecording(e.toString()))),
        );
      }
    }
  }

   void _stopRecordingAndSendHandler(LongPressEndDetails _) async {
    try {
      setState(() => _isRecording = false);
      final filePath = await ref.read(voiceServiceProvider).stopRecording();
      if (filePath == null) return;

      final settings = ref.read(settingsProvider);
      final notifier = ref.read(settingsProvider.notifier);
      final apiKey = await notifier.getApiKey(settings.provider) ?? '';

      await ref.read(summaryProvider.notifier).askFollowUpWithVoice(
            audioFilePath: filePath,
            originalText: widget.documents[_activeIndex].text,
            apiKey: apiKey,
            settings: settings,
            document: widget.documents[_activeIndex],
          );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.summarySheetFailedVoice(e.toString()))),
        );
      }
    }
  }

  late int _activeIndex;

  final _followUpCtrl = TextEditingController();
  final _followUpFocus = FocusNode();
  late AnimationController _entryController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _entryController = AnimationController(
      duration: animDuration(context, M3Tokens.durationSpring),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: M3Tokens.spatialSpring,
    ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: M3Tokens.effectsSpring,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
      _startSummary();
    });
  }

  Future<void> _startSummary() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.load();
    final settings = ref.read(settingsProvider);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    if (apiKey.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.summarySheetNoApiKey,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        if (mounted) _handleClose(context);
      }
      return;
    }

    await ref.read(summaryProvider.notifier).summarize(
          inputText: widget.documents[_activeIndex].text,
          apiKey: apiKey,
          settings: settings,
          document: widget.documents[_activeIndex],
        );
  }

   Future<void> _sendFollowUp() async {
    final question = _followUpCtrl.text.trim();
    if (question.isEmpty) return;
    _followUpCtrl.clear();
    _followUpFocus.unfocus();

    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    await ref.read(summaryProvider.notifier).askFollowUp(
          question: question,
          originalText: widget.documents[_activeIndex].text,
          apiKey: apiKey,
          settings: settings,
          document: widget.documents[_activeIndex],
        );

    // Scroll to bottom after sending follow-up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollCtrl?.hasClients ?? false) {
      _scrollCtrl?.animateTo(
        _scrollCtrl!.position.maxScrollExtent,
        duration: M3Tokens.durationStandard,
        curve: M3Tokens.effectsSpring,
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.summarySheetCopied)),
    );
  }

  Future<void> _factCheck() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    if (apiKey.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.summarySheetNoApiKey),
          ),
        );
      }
      return;
    }

    await ref.read(summaryProvider.notifier).factCheck(
          inputText: widget.documents[_activeIndex].text,
          apiKey: apiKey,
          settings: settings,
          document: widget.documents[_activeIndex],
        );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      _SlideUpRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();

    _followUpCtrl.dispose();
    _followUpFocus.dispose();
    // Don't use ref after dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     ref.listen<SummaryState>(summaryProvider, (prev, next) {
        if (prev?.status != SummaryStatus.done &&
            next.status == SummaryStatus.done) {
          widget.onSummarized?.call(next.summary);
        }
       if (prev?.status != SummaryStatus.error &&
           next.status == SummaryStatus.error) {
         widget.onSummaryFailed?.call(next.error);
       }
       // Auto-scroll when new chat messages are added
       if (prev != null && next.chat.length > prev.chat.length) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           _scrollToBottom();
         });
       }
     });
    final summaryState = ref.watch(summaryProvider);
    final notifier = ref.read(summaryProvider.notifier);

    // Auto-dismiss on error after 3 s
    if (summaryState.status == SummaryStatus.error) {
      Future<void>.delayed(const Duration(seconds: 3)).then((_) {
        if (mounted) _handleClose(context);
      });
    }

    Widget buildBody(ScrollController ctrl) => AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) => SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _SheetBody(
            scrollCtrl: ctrl,
            sheetScrollCtrl: ctrl,
            summaryState: summaryState,
            documents: widget.documents,
            activeIndex: _activeIndex,
            onIndexChanged: (i) => setState(() => _activeIndex = i),
            followUpCtrl: _followUpCtrl,
            followUpFocus: _followUpFocus,
            onCopy: () => _copyToClipboard(summaryState.summary),
            onReadAloud: () async {
              final settings = ref.read(settingsProvider);
              await notifier.startSpeaking(summaryState.summary, settings);
            },
            onPauseSpeaking: notifier.pauseSpeaking,
            onResumeSpeaking: notifier.resumeSpeaking,
            onStopSpeaking: notifier.stopSpeaking,
            onNewSummary: () async {
              await notifier.reset();
              await _startSummary();
            },
            onFactCheck: _factCheck,
            onClose: () => _handleClose(context),
            onSettings: _openSettings,
            onSendFollowUp: _sendFollowUp,
            isRecording: _isRecording,
            onLongPressStart: _startRecording,
            onLongPressEnd: _stopRecordingAndSendHandler,
            onRetryPdf: () async {
              final settings = ref.read(settingsProvider);
              final notifier = ref.read(settingsProvider.notifier);
              final apiKey =
                  await notifier.getApiKey(settings.provider) ?? '';
              await ref
                  .read(summaryProvider.notifier)
                  .retryPdfWithFallbackModel(
                    document: widget.documents[_activeIndex],
                    apiKey: apiKey,
                    settings: settings,
                  );
            },
          ),
        ),
      ),
    );

     if (widget.scrollController != null) {
       _scrollCtrl = widget.scrollController!;
       return buildBody(widget.scrollController!);
     }

     return DraggableScrollableSheet(
       initialChildSize: 0.8,
       minChildSize: 0.4,
       maxChildSize: 1.0,
       expand: false,
       builder: (_, sheetScrollCtrl) {
         _scrollCtrl = sheetScrollCtrl;
         return buildBody(sheetScrollCtrl);
       },
     );
  }

  void _handleClose(BuildContext context) {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollCtrl,
    required this.sheetScrollCtrl,
    required this.summaryState,
    required this.documents,
    required this.activeIndex,
    required this.onIndexChanged,
    required this.followUpCtrl,
    required this.followUpFocus,
    required this.onCopy,
    required this.onReadAloud,
    required this.onPauseSpeaking,
    required this.onResumeSpeaking,
    required this.onStopSpeaking,
    required this.onNewSummary,
    required this.onFactCheck,
    required this.onClose,
    required this.onSettings,
    required this.onSendFollowUp,
    required this.onRetryPdf,
    this.isRecording = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final ScrollController scrollCtrl;
  final ScrollController sheetScrollCtrl;
  final SummaryState summaryState;
  final List<Document> documents;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final TextEditingController followUpCtrl;
  final FocusNode followUpFocus;
  final VoidCallback onCopy;
  final VoidCallback onReadAloud;
  final VoidCallback onPauseSpeaking;
  final VoidCallback onResumeSpeaking;
  final VoidCallback onStopSpeaking;
  final VoidCallback onNewSummary;
  final VoidCallback onFactCheck;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final VoidCallback onSendFollowUp;
  final bool isRecording;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressEndDetails)? onLongPressEnd;
  final VoidCallback onRetryPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isStreaming = summaryState.status == SummaryStatus.streaming;
    final isDone = summaryState.status == SummaryStatus.done;
    final isError = summaryState.status == SummaryStatus.error;
    final isLoading = summaryState.status == SummaryStatus.loading;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

// Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: l10n.librarySettings,
                      onPressed: onSettings,
                    ),
                    Expanded(
                      child: Text(
                        summaryState.isFactChecking
                            ? l10n.summarySheetFactCheck
                            : l10n.summarySheetAiSummary,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.closeButton,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  children: [
                    if (documents.length > 1)
                      DocumentCarousel(
                        documents: documents,
                        activeIndex: activeIndex,
                        onIndexChanged: onIndexChanged,
                      ),
                    // Input text preview
                    _TextPreview(text: documents[activeIndex].text),
                    const SizedBox(height: 12),

                    // Loading shimmer
                    if (isLoading) const _ShimmerLoading(),

                    // Streaming / done summary
                    if (summaryState.summary.isNotEmpty || isStreaming) ...[
                      _SummaryContent(
                        summary: summaryState.summary,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Error message (shown briefly before auto-close)
                    if (isError)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.9 + (0.1 * value),
                            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                          );
                        },
                        child: Text(
                          summaryState.error,
                          style: TextStyle(color: cs.error),
                        ),
                      ),

                     // Chat history
                    if (summaryState.chat.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      ...summaryState.chat.map((msg) => _ChatBubble(msg: msg)),
                    ],

                    // Streaming follow-up reply
                    if (summaryState.streamingReply.isNotEmpty)
                      _ChatBubble(
                        msg: null,
                        streamingContent: summaryState.streamingReply,
                        isCursorVisible: summaryState.isCursorVisible,
                      ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Warnings (e.g., scanned PDF)
              if (isDone && summaryState.warnings.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: cs.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summaryState.warnings.first,
                          style: TextStyle(
                            color: cs.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (summaryState.source == 'pdf')
                        TextButton(
                          onPressed: onRetryPdf,
                          child: Text(l10n.retryButton),
                        ),
                    ],
                  ),
                ),
              ],

              // Action buttons (shown when done)
              if (isDone) ...[
                const Divider(height: 1),
                _ActionBar(
                  ttsState: summaryState.ttsState,
                  onReadAloud: onReadAloud,
                  onPauseSpeaking: onPauseSpeaking,
                  onResumeSpeaking: onResumeSpeaking,
                  onStopSpeaking: onStopSpeaking,
                  onCopy: onCopy,
                  onFactCheck: onFactCheck,
                ),
              ],

              // Follow-up input (shown when done and under 3 turns)
              if (isDone &&
                  summaryState.followUpCount < 3 &&
                  summaryState.chat.length < 6) ...[
                const Divider(height: 1),
                _FollowUpInput(
                  controller: followUpCtrl,
                  focusNode: followUpFocus,
                  onSend: onSendFollowUp,
                  remainingTurns: 3 - summaryState.followUpCount,
                  isRecording: isRecording,
                  onLongPressStart: onLongPressStart,
                  onLongPressEnd: onLongPressEnd,
                ),
              ] else ...[
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MarkdownBody(
          data: summary,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatefulWidget {
  const _ShimmerLoading();

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainerHigh;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerLine(
                  width: double.infinity,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animation: _controller,
                ),
                const SizedBox(height: 8),
                _ShimmerLine(
                  width: constraints.maxWidth * 0.85,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animation: _controller,
                ),
                const SizedBox(height: 8),
                _ShimmerLine(
                  width: constraints.maxWidth * 0.7,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animation: _controller,
                ),
                const SizedBox(height: 8),
                _ShimmerLine(
                  width: constraints.maxWidth * 0.6,
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  animation: _controller,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({
    required this.width,
    required this.baseColor,
    required this.highlightColor,
    required this.animation,
  });

  final double width;
  final Color baseColor;
  final Color highlightColor;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2 * animation.value, 0),
          end: Alignment(1.0 + 2 * animation.value, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    this.msg,
    this.streamingContent,
    this.isCursorVisible = false,
  });

  final ChatMessage? msg;
  final String? streamingContent;
  final bool isCursorVisible;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = msg?.role == 'user';
    final content = streamingContent ?? msg?.content ?? '';
    final displayContent =
        streamingContent != null && isCursorVisible ? '$content▋' : content;

return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isUser
                  ? cs.primaryContainer.withValues(alpha: 0.76)
                  : cs.secondaryContainer.withValues(alpha: 0.76),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: streamingContent != null || msg?.role == 'assistant'
                ? MarkdownBody(
                    data: displayContent,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  )
                : Text(
                    displayContent,
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.ttsState,
    required this.onReadAloud,
    required this.onPauseSpeaking,
    required this.onResumeSpeaking,
    required this.onStopSpeaking,
    required this.onCopy,
    required this.onFactCheck,
  });

  final TtsState ttsState;
  final VoidCallback onReadAloud;
  final VoidCallback onPauseSpeaking;
  final VoidCallback onResumeSpeaking;
  final VoidCallback onStopSpeaking;
  final VoidCallback onCopy;
  final VoidCallback onFactCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final IconData ttsIcon;
    final String ttsLabel;
    final VoidCallback ttsTap;

    switch (ttsState) {
      case TtsState.stopped:
        ttsIcon = Icons.volume_up_outlined;
        ttsLabel = l10n.summarySheetReadAloud;
        ttsTap = onReadAloud;
      case TtsState.playing:
        ttsIcon = Icons.pause_circle_outline;
        ttsLabel = l10n.summarySheetPause;
        ttsTap = onPauseSpeaking;
      case TtsState.paused:
        ttsIcon = Icons.play_circle_outline;
        ttsLabel = l10n.summarySheetResume;
        ttsTap = onResumeSpeaking;
    }

    final ttsColor = ttsState == TtsState.stopped ? null : cs.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.copy_outlined,
            label: l10n.summarySheetCopy,
            onTap: onCopy,
          ),
          _ActionButton(
            icon: ttsIcon,
            label: ttsLabel,
            onTap: ttsTap,
            iconColor: ttsColor,
          ),
          if (ttsState != TtsState.stopped)
            _ActionButton(
              icon: Icons.stop_circle_outlined,
              label: l10n.summarySheetStop,
              onTap: onStopSpeaking,
            ),
          _ActionButton(
            icon: Icons.fact_check_outlined,
            label: l10n.summarySheetFactCheck,
            onTap: onFactCheck,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: animDuration(context, M3Tokens.durationStandard),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _controller,
        curve: M3Tokens.buttonPressCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        onTapDown: (_) => _controller.forward(),
        onTapCancel: () => _controller.reverse(),
        onHighlightChanged: (h) {
          if (!h) _controller.reverse();
        },
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 22, color: widget.iconColor),
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FollowUpInput extends StatefulWidget {
  const _FollowUpInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.remainingTurns,
    required this.isRecording,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final int remainingTurns;
  final bool isRecording;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressEndDetails)? onLongPressEnd;

  @override
  State<_FollowUpInput> createState() => _FollowUpInputState();
}

class _FollowUpInputState extends State<_FollowUpInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: animDuration(context, const Duration(milliseconds: 800)),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_FollowUpInput old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _pulseCtrl.repeat();
    } else if (!widget.isRecording && old.isRecording) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _buildButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.isRecording ? cs.error : cs.primary;
    return GestureDetector(
      onTap: widget.isRecording ? null : widget.onSend,
      onLongPressStart: widget.onLongPressStart,
      onLongPressEnd: widget.onLongPressEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) => Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.error, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(
              widget.isRecording ? Icons.mic : Icons.send,
              color: cs.onPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    final bottom = 8.0 + mq.viewInsets.bottom + mq.padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom),
      child: Row(
        children: [
          Expanded(
            child: widget.isRecording
                ? const SizedBox.shrink()
                : TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                    decoration: InputDecoration(
                      hintText: widget.remainingTurns == 1
                          ? l10n.summarySheetLastFollowUp
                          : l10n.summarySheetFollowUpHint,
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
          ),
          if (!widget.isRecording) const SizedBox(width: 8),
          _buildButton(context),
        ],
      ),
    );
  }
}

class _SlideUpRoute<T> extends PageRouteBuilder<T> {
  _SlideUpRoute({required WidgetBuilder builder})
      : super(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
            backgroundColor: Colors.transparent,
            body: builder(context),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.elasticOut;

            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: M3Tokens.durationPage,
        );
}

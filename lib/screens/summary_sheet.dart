import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/summary_state.dart';
import '../providers/settings_provider.dart';
import '../providers/summary_provider.dart';
import 'settings_screen.dart';

class SummarySheet extends ConsumerStatefulWidget {
  const SummarySheet({super.key, required this.initialText});

  final String initialText;

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _followUpCtrl = TextEditingController();
  final _followUpFocus = FocusNode();
  late AnimationController _entryController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOut,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
      _startSummary();
    });
  }

  Future<void> _startSummary() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No API key configured. Open Settings first.',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    await ref.read(summaryProvider.notifier).summarize(
          inputText: widget.initialText,
          apiKey: apiKey,
          settings: settings,
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
          originalText: widget.initialText,
          apiKey: apiKey,
          settings: settings,
        );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _factCheck() async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final apiKey = await notifier.getApiKey(settings.provider) ?? '';

    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No API key configured. Open Settings first.'),
          ),
        );
      }
      return;
    }

    await ref.read(summaryProvider.notifier).factCheck(
          inputText: widget.initialText,
          apiKey: apiKey,
          settings: settings,
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
    _scrollCtrl.dispose();
    _followUpCtrl.dispose();
    _followUpFocus.dispose();
    ref.read(summaryProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryState = ref.watch(summaryProvider);
    final notifier = ref.read(summaryProvider.notifier);

    // Auto-dismiss on error after 3 s
    if (summaryState.status == SummaryStatus.error) {
      Future<void>.delayed(const Duration(seconds: 3)).then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, sheetScrollCtrl) {
        return AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _SheetBody(
                  scrollCtrl: _scrollCtrl,
                  sheetScrollCtrl: sheetScrollCtrl,
                  summaryState: summaryState,
                  initialText: widget.initialText,
                  followUpCtrl: _followUpCtrl,
                  followUpFocus: _followUpFocus,
                  onCopy: () => _copyToClipboard(summaryState.summary),
                  onReadAloud: () async {
                    final settings = ref.read(settingsProvider);
                    await notifier.startSpeaking(
                        summaryState.summary, settings);
                  },
                  onPauseSpeaking: notifier.pauseSpeaking,
                  onResumeSpeaking: notifier.resumeSpeaking,
                  onStopSpeaking: notifier.stopSpeaking,
                  onNewSummary: () async {
                    await notifier.reset();
                    await _startSummary();
                  },
                  onFactCheck: _factCheck,
                  onClose: () => Navigator.of(context).pop(),
                  onSettings: _openSettings,
                  onSendFollowUp: _sendFollowUp,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollCtrl,
    required this.sheetScrollCtrl,
    required this.summaryState,
    required this.initialText,
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
  });

  final ScrollController scrollCtrl;
  final ScrollController sheetScrollCtrl;
  final SummaryState summaryState;
  final String initialText;
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

  @override
  Widget build(BuildContext context) {
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
            color: cs.surface.withValues(alpha: 0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: onSettings,
                ),
                Expanded(
                  child: Text(
                    summaryState.isFactChecking ? 'Fact Check' : 'AI Summary',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
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
                // Input text preview
                _TextPreview(text: initialText),
                const SizedBox(height: 12),

                // Loading shimmer
                if (isLoading) const _ShimmerLoading(),

                // Streaming / done summary
                if (summaryState.summary.isNotEmpty || isStreaming) ...[
                  _SummaryContent(
                    summary: summaryState.summary,
                    isCursorVisible: summaryState.isCursorVisible,
                    isStreaming: isStreaming,
                  ),
                  const SizedBox(height: 8),
                ],

                // Error message (shown briefly before auto-close)
                if (isError)
                  Text(
                    summaryState.error,
                    style: TextStyle(color: cs.error),
                  ),

                // Chat history
                if (summaryState.chat.isNotEmpty) ...[
                  const Divider(),
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
            ),
          ],

          // Safe area bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
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
  const _SummaryContent({
    required this.summary,
    required this.isCursorVisible,
    required this.isStreaming,
  });

  final String summary;
  final bool isCursorVisible;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final displayText = isStreaming && isCursorVisible ? '$summary▋' : summary;

    return MarkdownBody(
      data: displayText,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
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
                animation: _controller),
            const SizedBox(height: 8),
            _ShimmerLine(
                width: MediaQuery.of(context).size.width * 0.85,
                baseColor: baseColor,
                highlightColor: highlightColor,
                animation: _controller),
            const SizedBox(height: 8),
            _ShimmerLine(
                width: MediaQuery.of(context).size.width * 0.7,
                baseColor: baseColor,
                highlightColor: highlightColor,
                animation: _controller),
            const SizedBox(height: 8),
            _ShimmerLine(
                width: MediaQuery.of(context).size.width * 0.6,
                baseColor: baseColor,
                highlightColor: highlightColor,
                animation: _controller),
          ],
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

    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? cs.primaryContainer : cs.secondaryContainer,
          borderRadius: radius,
        ),
        child: streamingContent != null || msg?.role == 'assistant'
            ? MarkdownBody(
                data: displayContent,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
              )
            : Text(
                displayContent,
                style: TextStyle(color: cs.onPrimaryContainer),
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
    final cs = Theme.of(context).colorScheme;
    final IconData ttsIcon;
    final String ttsLabel;
    final VoidCallback ttsTap;

    switch (ttsState) {
      case TtsState.stopped:
        ttsIcon = Icons.volume_up_outlined;
        ttsLabel = 'Read Aloud';
        ttsTap = onReadAloud;
      case TtsState.playing:
        ttsIcon = Icons.pause_circle_outline;
        ttsLabel = 'Pause';
        ttsTap = onPauseSpeaking;
      case TtsState.paused:
        ttsIcon = Icons.play_circle_outline;
        ttsLabel = 'Resume';
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
            label: 'Copy',
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
              label: 'Stop',
              onTap: onStopSpeaking,
            ),
          _ActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Fact Check',
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
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

class _FollowUpInput extends StatelessWidget {
  const _FollowUpInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.remainingTurns,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final int remainingTurns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: remainingTurns == 1
                    ? 'Last follow-up question...'
                    : 'Ask a follow-up question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            onPressed: onSend,
          ),
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
            const curve = Curves.easeOutCubic;

            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}

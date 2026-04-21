import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/meeting.dart';
import '../providers/import_service_provider.dart';
import '../providers/meeting_library_provider.dart';
import '../providers/meeting_provider.dart';
import '../widgets/meeting_share_sheet.dart';
import 'archived_meetings_screen.dart';
import 'meeting_detail_screen.dart';
import 'recording_screen.dart';
import 'settings_screen.dart';

class MeetingLibraryScreen extends ConsumerWidget {
  const MeetingLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meetingsAsync = ref.watch(meetingLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: l10n.libraryImportFile,
            onPressed: () => _importFile(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: l10n.libraryArchived,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ArchivedMeetingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.librarySettings,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: meetingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.libraryError(e.toString())),
            ),
          ),
          data: (meetings) => _buildList(meetings, l10n),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _startRecording(context, ref);
        },
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _buildList(List<Meeting> meetings, AppLocalizations l10n) {
    if (meetings.isEmpty) {
      return Center(child: Text(l10n.libraryNoItems));
    }
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        itemCount: meetings.length,
        itemBuilder: (ctx, i) => _MeetingTile(meeting: meetings[i]),
      ),
    );
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m4a', 'mp3', 'wav', 'flac', 'aac', 'ogg', 'webm', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    try {
      final meeting = await ref.read(importServiceProvider).importFile(filePath);
      if (meeting == null) return;
      ref.read(meetingLibraryProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.libraryImportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _startRecording(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const RecordingScreen()),
    );
    ref.read(meetingLibraryProvider.notifier).refresh();
  }
}

class _MeetingTile extends ConsumerWidget {
  final Meeting meeting;

  const _MeetingTile({required this.meeting});

@override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.watch(meetingProvider(meeting.id).notifier);
    final cs = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey(meeting.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => showMeetingShareSheet(context, meeting),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            icon: Icons.share,
            label: l10n.libraryShare,
          ),
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context, notifier),
            backgroundColor: cs.secondary,
            foregroundColor: cs.onSecondary,
            icon: Icons.edit,
            label: l10n.libraryRename,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => _archive(context, notifier),
            backgroundColor: cs.tertiary,
            foregroundColor: cs.onTertiary,
            icon: Icons.archive,
            label: l10n.libraryArchive,
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, notifier),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete,
            label: l10n.libraryDelete,
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          meeting.type == MeetingType.document
              ? Icons.article_outlined
              : Icons.mic_none,
        ),
        title: Text(meeting.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                meeting.type == MeetingType.document
                    ? _formatDateTime(context, meeting.createdAt)
                    : '${_formatDuration(meeting.durationSec)} • ${_formatDateTime(context, meeting.createdAt)}',
              ),
            if (meeting.lastError != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 12,),
                  const SizedBox(width: 4),
                  Text(
                    l10n.libraryFailedDetails,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: _ActionButton(meeting: meeting, notifier: notifier),
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MeetingDetailScreen(meetingId: meeting.id),
            ),
          );
          ref.read(meetingLibraryProvider.notifier).refresh();
        },
      ),
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

  void _archive(BuildContext context, MeetingNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    notifier.archive();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.libraryArchivedSnackbar),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.undoButton,
          onPressed: notifier.unarchive,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MeetingNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meeting.type == MeetingType.document
            ? l10n.libraryDeleteDocument
            : l10n.libraryDeleteMeeting,),
        content: Text(meeting.type == MeetingType.document
            ? l10n.libraryDeleteDocumentConfirm
            : l10n.libraryDeleteMeetingConfirm,),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () {
              notifier.delete();
              Navigator.pop(ctx);
            },
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, MeetingNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: meeting.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryRenameMeeting),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () {
              notifier.rename(controller.text);
              Navigator.pop(ctx);
            },
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Meeting meeting;
  final MeetingNotifier notifier;

  const _ActionButton({required this.meeting, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    switch (meeting.status) {
      case MeetingStatus.recorded:
        if (meeting.type == MeetingType.document) {
          return ElevatedButton(
            onPressed: () => notifier.summarize(),
            child: Text(l10n.summarizeButton),
          );
        }
        return ElevatedButton(
          onPressed: () => notifier.transcribe(),
          child: Text(l10n.transcribeButton),
        );
      case MeetingStatus.transcribing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MeetingStatus.transcribed:
        return ElevatedButton(
          onPressed: () => notifier.summarize(),
          child: Text(l10n.summarizeButton),
        );
      case MeetingStatus.summarizing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MeetingStatus.done:
        return Icon(Icons.check_circle, color: cs.primary);
      case MeetingStatus.failed:
        if (meeting.type == MeetingType.document) {
          return Icon(Icons.error_outline, color: cs.error);
        }
        return ElevatedButton(
          onPressed: () => notifier.retry(),
          child: Text(l10n.retryButton),
        );
    }
  }
}

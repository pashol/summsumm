import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/meeting.dart';
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
    final meetingsAsync = ref.watch(meetingLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const ArchivedMeetingsScreen(),),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: meetingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (meetings) => _buildList(meetings),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startRecording(context, ref),
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _buildList(List<Meeting> meetings) {
    if (meetings.isEmpty) {
      return const Center(child: Text('No items yet'));
    }
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        itemCount: meetings.length,
        itemBuilder: (ctx, i) => _MeetingTile(meeting: meetings[i]),
      ),
    );
  }

  Future<void> _startRecording(BuildContext context, WidgetRef ref) async {
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
    final notifier = ref.watch(meetingProvider(meeting.id).notifier);

    return Slidable(
      key: ValueKey(meeting.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => showMeetingShareSheet(context, meeting),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            icon: Icons.share,
            label: 'Share',
          ),
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context, notifier),
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Rename',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) => _archive(context, notifier),
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
            icon: Icons.archive,
            label: 'Archive',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, notifier),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
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
                  ? '${meeting.createdAt}'
                  : '${_formatDuration(meeting.durationSec)} • ${meeting.createdAt}',
            ),
            if (meeting.lastError != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Failed — tap for details',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: _ActionButton(meeting: meeting, notifier: notifier),
        onTap: () async {
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

  void _archive(BuildContext context, MeetingNotifier notifier) {
    notifier.archive();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Meeting archived'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: notifier.unarchive,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MeetingNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meeting.type == MeetingType.document
            ? 'Delete Document?'
            : 'Delete Meeting?'),
        content: Text(meeting.type == MeetingType.document
            ? 'This will permanently delete this document summary.'
            : 'This will permanently delete the recording and all data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, MeetingNotifier notifier) {
    final controller = TextEditingController(text: meeting.title);
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
              notifier.rename(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
    switch (meeting.status) {
      case MeetingStatus.recorded:
        return ElevatedButton(
          onPressed: () => notifier.transcribe(),
          child: const Text('Transcribe'),
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
          child: const Text('Summarize'),
        );
      case MeetingStatus.summarizing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MeetingStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MeetingStatus.failed:
        if (meeting.type == MeetingType.document) {
          return const Icon(Icons.error_outline, color: Colors.red);
        }
        return ElevatedButton(
          onPressed: () => notifier.retry(),
          child: const Text('Retry'),
        );
    }
  }
}

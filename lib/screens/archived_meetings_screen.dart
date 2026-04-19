import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../models/meeting.dart';
import '../providers/meeting_library_provider.dart';
import '../providers/meeting_provider.dart';
import '../widgets/meeting_share_sheet.dart';
import 'meeting_detail_screen.dart';

class ArchivedMeetingsScreen extends ConsumerWidget {
  const ArchivedMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(archivedMeetingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Meetings')),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: meetingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (meetings) {
            if (meetings.isEmpty) {
              return const Center(child: Text('No archived meetings'));
            }
            return SlidableAutoCloseBehavior(
              child: ListView.builder(
                itemCount: meetings.length,
                itemBuilder: (ctx, i) =>
                    _ArchivedMeetingTile(meeting: meetings[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArchivedMeetingTile extends ConsumerWidget {
  final Meeting meeting;

  const _ArchivedMeetingTile({required this.meeting});

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
            onPressed: (_) => _unarchive(context, notifier),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.unarchive,
            label: 'Restore',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
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
                    'Failed — tap for details',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MeetingDetailScreen(meetingId: meeting.id),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context);
    return DateFormat.yMMMd(locale.languageCode).add_jm().format(dateTime.toLocal());
  }

  void _unarchive(BuildContext context, MeetingNotifier notifier) {
    notifier.unarchive();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting restored to library')),
    );
  }

  void _confirmDelete(BuildContext context, MeetingNotifier notifier) {
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
              notifier.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

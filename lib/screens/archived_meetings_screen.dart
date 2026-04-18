import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/meeting.dart';
import '../providers/meeting_library_provider.dart';
import '../providers/meeting_provider.dart';
import 'meeting_detail_screen.dart';

class ArchivedMeetingsScreen extends ConsumerWidget {
  const ArchivedMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(archivedMeetingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Meetings')),
      body: meetingsAsync.when(
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
        extentRatio: 0.3,
        children: [
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
        title: Text(meeting.title),
        subtitle: Text(_formatDuration(meeting.durationSec)),
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
        title: const Text('Delete Meeting?'),
        content: const Text(
            'This will permanently delete the recording and all data.',),
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

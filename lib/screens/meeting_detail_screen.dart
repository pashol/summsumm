import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/providers/meeting_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/widgets/meeting_share_sheet.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  bool _diarize = false;

  @override
  Widget build(BuildContext context) {
    final meeting = ref.watch(meetingProvider(widget.meetingId));
    final provider = ref.watch(meetingProvider(widget.meetingId).notifier);
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetadata(meeting),
              const SizedBox(height: 20),
              if (meeting.transcript != null) ...[
                const Text('Transcript', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(meeting.transcript!),
                const SizedBox(height: 20),
              ],
              if (meeting.summary != null) ...[
                const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                MarkdownBody(data: meeting.summary!),
                const SizedBox(height: 20),
              ],
              _buildActions(meeting, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(Meeting meeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meeting.type == MeetingType.meeting)
          Text('Duration: ${_formatDuration(meeting.durationSec)}'),
        Text('Recorded: ${meeting.createdAt}'),
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
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meeting.lastError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(Meeting meeting, MeetingNotifier provider) {
    if (meeting.status == MeetingStatus.recorded) {
      final settings = ref.watch(settingsProvider);
      final isOpenRouter = settings.provider == 'openrouter';

      return Column(
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
                    color: isOpenRouter ? null : Theme.of(context).disabledColor,
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
      );
    }
    if (meeting.status == MeetingStatus.transcribed) {
      return ElevatedButton(
        onPressed: provider.summarize,
        child: const Text('Summarize'),
      );
    }
    if (meeting.status == MeetingStatus.failed) {
      if (meeting.type == MeetingType.document) return const SizedBox.shrink();
      return ElevatedButton(
        onPressed: provider.retry,
        child: const Text('Retry'),
      );
    }
    return const SizedBox.shrink();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
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

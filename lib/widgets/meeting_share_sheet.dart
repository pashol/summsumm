import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/meeting.dart';

class MeetingShareSheet extends StatelessWidget {
  final Meeting meeting;

  const MeetingShareSheet({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Share',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (meeting.type == MeetingType.meeting)
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: const Text('Share Audio'),
              onTap: () => _shareAudio(context),
            ),
          if (meeting.transcript != null)
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share Transcript'),
              onTap: () => _shareText(context, meeting.transcript!),
            ),
          if (meeting.summaries.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Share Summary'),
              onTap: () => _shareText(context, meeting.summary!),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _shareAudio(BuildContext context) async {
    Navigator.pop(context);
    final file = File(meeting.audioPath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file not found')),
        );
      }
      return;
    }
    await Share.shareXFiles(
      [XFile(meeting.audioPath)],
      subject: meeting.title,
    );
  }

  Future<void> _shareText(BuildContext context, String text) async {
    Navigator.pop(context);
    await Share.share(text, subject: meeting.title);
  }
}

void showMeetingShareSheet(BuildContext context, Meeting meeting) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => MeetingShareSheet(meeting: meeting),
  );
}

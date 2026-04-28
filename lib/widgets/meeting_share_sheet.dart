import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/meeting.dart';
import '../services/pdf_export_service.dart';

class MeetingShareSheet extends StatelessWidget {
  final Meeting meeting;

  const MeetingShareSheet({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.shareTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (meeting.type == MeetingType.meeting)
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: Text(l10n.shareAudio),
              onTap: () => _shareAudio(context),
            ),
          if (meeting.transcript != null)
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: Text(l10n.shareTranscript),
              onTap: () => _shareText(context, meeting.transcript!),
            ),
          if (meeting.summaries.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: Text(l10n.shareSummary),
              onTap: () => _shareText(context, meeting.summary!),
            ),
          if (meeting.summaries.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.exportSummaryPdf),
              onTap: () => _exportSummaryPdf(context),
            ),
          if (meeting.transcript != null)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.exportTranscriptPdf),
              onTap: () => _exportTranscriptPdf(context),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _shareAudio(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    Navigator.pop(context);
    final file = File(meeting.audioPath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shareAudioNotFound)),
        );
      }
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final safeTitle = meeting.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final ext = p.extension(meeting.audioPath);
    final tempFileName = '$safeTitle$ext';
    final tempPath = p.join(tempDir.path, tempFileName);
    await file.copy(tempPath);

    await Share.shareXFiles(
      [XFile(tempPath, name: tempFileName)],
      subject: meeting.title,
    );
  }

  Future<void> _shareText(BuildContext context, String text) async {
    Navigator.pop(context);
    await Share.share(text, subject: meeting.title);
  }

  Future<void> _exportSummaryPdf(BuildContext context) async {
    Navigator.pop(context);
    try {
      final path = await PdfExportService.exportSummary(meeting);
      await Share.shareXFiles(
        [XFile(path)],
        subject: '${meeting.title} - Summary',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportTranscriptPdf(BuildContext context) async {
    Navigator.pop(context);
    try {
      final path = await PdfExportService.exportTranscript(meeting);
      await Share.shareXFiles(
        [XFile(path)],
        subject: '${meeting.title} - Transcript',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }
}

void showMeetingShareSheet(BuildContext context, Meeting meeting) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => MeetingShareSheet(meeting: meeting),
  );
}

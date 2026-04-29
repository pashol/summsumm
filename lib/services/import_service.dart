import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:uuid/uuid.dart';

typedef DocumentTextExtractor = Future<String> Function(String path);

const _largePdfThresholdBytes = 1536 * 1024;

String _extractPdfTextFromBytes(List<int> bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

String _normalizeDocumentText(String text) {
  const paragraphBreak = '\u0000PDF_PARAGRAPH_BREAK\u0000';
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), paragraphBreak)
      .replaceAll(RegExp(r'\n+'), ' ')
      .replaceAll(paragraphBreak, '\n\n')
      .trim();
}

Future<String> _extractPdfText(String path) async {
  final bytes = await File(path).readAsBytes();
  if (bytes.length > _largePdfThresholdBytes) {
    return Isolate.run(() => _extractPdfTextFromBytes(bytes));
  }
  return _extractPdfTextFromBytes(bytes);
}

class ImportService {
  final MeetingRepository _repository;
  final Future<Directory> Function()? _getMeetingsDir;
  final DocumentTextExtractor _documentTextExtractor;
  static const MethodChannel _channel = MethodChannel('app.summsumm/intent');

  ImportService(
    this._repository, {
    Future<Directory> Function()? getMeetingsDir,
    DocumentTextExtractor? documentTextExtractor,
  })  : _getMeetingsDir = getMeetingsDir,
        _documentTextExtractor = documentTextExtractor ?? _extractPdfText;

  static const _audioExtensions = {
    'm4a',
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'webm',
  };
  static const _documentExtensions = {'pdf'};

  Future<Meeting?> importFile(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase().replaceAll('.', '');

    final MeetingType type;
    if (_audioExtensions.contains(ext)) {
      type = MeetingType.meeting;
    } else if (_documentExtensions.contains(ext)) {
      type = MeetingType.document;
    } else {
      return null;
    }

    final meetingsDir = await _resolveMeetingsDir();
    final id = const Uuid().v4();
    final destPath = p.join(meetingsDir.path, '$id.$ext');
    await File(sourcePath).copy(destPath);

    final title = p.basenameWithoutExtension(sourcePath);

    // Read duration for audio files using fast native metadata retrieval
    int durationSec = 0;
    if (type == MeetingType.meeting) {
      durationSec = await _getAudioDuration(destPath);
    }

    String? documentText;
    if (type == MeetingType.document) {
      try {
        documentText = _normalizeDocumentText(
          await _documentTextExtractor(destPath),
        );
      } catch (_) {
        documentText = null;
      }
    }

    final meeting = Meeting(
      id: id,
      createdAt: DateTime.now(),
      durationSec: durationSec,
      audioPath: destPath,
      title: title,
      status: MeetingStatus.recorded,
      type: type,
      rawTranscript: documentText?.trim().isEmpty ?? true ? null : documentText,
    );

    await _repository.save(meeting);
    return meeting;
  }

  Future<Directory> _resolveMeetingsDir() async {
    final getter = _getMeetingsDir;
    if (getter != null) return getter();
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'meetings'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Returns audio duration in seconds using MediaMetadataRetriever (Android).
  /// This reads metadata only - much faster than decoding the file.
  Future<int> _getAudioDuration(String filePath) async {
    try {
      final result = await _channel
          .invokeMethod<int>('getAudioDuration', {'path': filePath});
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

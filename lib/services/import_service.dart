import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart' as rag;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:uuid/uuid.dart';

typedef DocumentTextExtractor = Future<String> Function(String path);
typedef ImportedDocumentUpdated = FutureOr<void> Function(Meeting meeting);

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

Future<String> _extractDocumentText(String path) async {
  if (!rag.MobileRag.isInitialized) {
    await rag.MobileRag.initialize(
      tokenizerAsset: 'assets/rag/tokenizer.json',
      modelAsset: 'assets/rag/model.onnx',
      databaseName: 'library_rag.sqlite',
      threadLevel: rag.ThreadUseLevel.medium,
      deferIndexWarmup: true,
    );
  }
  return rag.extractTextFromFile(filePath: path);
}

class ImportService {
  final MeetingRepository _repository;
  final Future<Directory> Function()? _getMeetingsDir;
  final DocumentTextExtractor _documentTextExtractor;
  final ImportedDocumentUpdated? _onDocumentUpdated;
  static const MethodChannel _channel = MethodChannel('app.summsumm/intent');

  ImportService(
    this._repository, {
    Future<Directory> Function()? getMeetingsDir,
    DocumentTextExtractor? documentTextExtractor,
    ImportedDocumentUpdated? onDocumentUpdated,
  }) : _getMeetingsDir = getMeetingsDir,
       _documentTextExtractor = documentTextExtractor ?? _extractDocumentText,
       _onDocumentUpdated = onDocumentUpdated;

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

    return _import(
      sourceName: p.basename(sourcePath),
      ext: ext,
      copyTo: (destPath) => File(sourcePath).copy(destPath),
    );
  }

  Future<Meeting?> importStream({
    required String sourceName,
    required Stream<List<int>> stream,
  }) async {
    final ext = p.extension(sourceName).toLowerCase().replaceAll('.', '');

    return _import(
      sourceName: sourceName,
      ext: ext,
      copyTo: (destPath) async {
        final output = File(destPath).openWrite();
        try {
          await stream.pipe(output);
        } catch (_) {
          await output.close();
          rethrow;
        }
      },
    );
  }

  Future<Meeting?> _import({
    required String sourceName,
    required String ext,
    required FutureOr<void> Function(String destPath) copyTo,
  }) async {
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
    await copyTo(destPath);

    final title = p.basenameWithoutExtension(sourceName);

    // Read duration for audio files using fast native metadata retrieval
    int durationSec = 0;
    if (type == MeetingType.meeting) {
      durationSec = await _getAudioDuration(destPath);
    }

    final meeting = Meeting(
      id: id,
      createdAt: DateTime.now(),
      durationSec: durationSec,
      audioPath: destPath,
      title: title,
      status: MeetingStatus.recorded,
      type: type,
    );

    await _repository.save(meeting);
    if (type == MeetingType.document) {
      unawaited(_extractAndSaveDocumentText(meeting));
    }
    return meeting;
  }

  Future<void> _extractAndSaveDocumentText(Meeting meeting) async {
    try {
      final documentText = _normalizeDocumentText(
        await _documentTextExtractor(meeting.audioPath),
      );
      if (documentText.trim().isEmpty) return;

      final updated = meeting.copyWith(rawTranscript: documentText);
      await _repository.save(updated);
      await _onDocumentUpdated?.call(updated);
    } catch (_) {
      // Keep the imported PDF in the library even if local text extraction fails.
    }
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
      final result = await _channel.invokeMethod<int>('getAudioDuration', {
        'path': filePath,
      });
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

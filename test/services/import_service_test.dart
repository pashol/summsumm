import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/import_service.dart';
import 'package:summsumm/services/meeting_repository.dart';

class _FakeRepository extends MeetingRepository {
  final List<Meeting> saved = [];

  @override
  Future<void> save(Meeting meeting) async => saved.add(meeting);
}

void main() {
  late Directory tempDir;
  late Directory meetingsDir;
  late _FakeRepository repo;
  late ImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_test_');
    meetingsDir = Directory(p.join(tempDir.path, 'meetings'));
    await meetingsDir.create();
    repo = _FakeRepository();
    service = ImportService(
      repo,
      getMeetingsDir: () async => meetingsDir,
      documentTextExtractor: (_) async => '',
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> makeSourceFile(String name, [String content = 'data']) async {
    final f = File(p.join(tempDir.path, name));
    await f.writeAsString(content);
    return f;
  }

  test('imports audio file as MeetingType.meeting', () async {
    final source = await makeSourceFile('interview.m4a');
    final meeting = await service.importFile(source.path);

    expect(meeting, isNotNull);
    expect(meeting!.type, MeetingType.meeting);
    expect(meeting.status, MeetingStatus.recorded);
    expect(meeting.title, 'interview');
    expect(meeting.durationSec, 0);
    expect(File(meeting.audioPath).existsSync(), isTrue);
    expect(repo.saved, hasLength(1));
  });

  test(
    'imports audio stream when source path is not directly readable',
    () async {
      final meeting = await service.importStream(
        sourceName: 'downloaded.aac',
        stream: Stream<List<int>>.fromIterable([
          [1, 2, 3],
          [4, 5],
        ]),
      );

      expect(meeting, isNotNull);
      expect(meeting!.type, MeetingType.meeting);
      expect(meeting.title, 'downloaded');
      expect(meeting.audioPath, endsWith('.aac'));
      expect(await File(meeting.audioPath).readAsBytes(), [1, 2, 3, 4, 5]);
      expect(repo.saved, hasLength(1));
    },
  );

  test('imports PDF as MeetingType.document', () async {
    final source = await makeSourceFile('report.pdf');
    final meeting = await service.importFile(source.path);

    expect(meeting, isNotNull);
    expect(meeting!.type, MeetingType.document);
    expect(meeting.status, MeetingStatus.recorded);
    expect(meeting.title, 'report');
    expect(File(meeting.audioPath).existsSync(), isTrue);
    expect(repo.saved, hasLength(1));
  });

  test('stores extracted PDF text as document content', () async {
    service = ImportService(
      repo,
      getMeetingsDir: () async => meetingsDir,
      documentTextExtractor: (_) async => 'Extracted document text',
    );
    final source = await makeSourceFile('report.pdf');

    final meeting = await service.importFile(source.path);
    await Future<void>.delayed(Duration.zero);

    expect(meeting!.rawTranscript, isNull);
    expect(repo.saved.last.rawTranscript, 'Extracted document text');
  });

  test('adds PDF to the library before text extraction finishes', () async {
    final extraction = Completer<String>();
    service = ImportService(
      repo,
      getMeetingsDir: () async => meetingsDir,
      documentTextExtractor: (_) => extraction.future,
    );
    final source = await makeSourceFile('report.pdf');

    final meeting = await service.importFile(source.path);

    expect(meeting, isNotNull);
    expect(meeting!.rawTranscript, isNull);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.rawTranscript, isNull);

    extraction.complete('Extracted later');
    await Future<void>.delayed(Duration.zero);

    expect(repo.saved, hasLength(2));
    expect(repo.saved.last.id, meeting.id);
    expect(repo.saved.last.rawTranscript, 'Extracted later');
  });

  test('normalizes extracted document text before storing it', () async {
    service = ImportService(
      repo,
      getMeetingsDir: () async => meetingsDir,
      documentTextExtractor: (_) async =>
          'First\nwrapped   line\n\n\nSecond paragraph',
    );
    final source = await makeSourceFile('report.pdf');

    await service.importFile(source.path);
    await Future<void>.delayed(Duration.zero);

    expect(
      repo.saved.last.rawTranscript,
      'First wrapped line\n\nSecond paragraph',
    );
  });

  test('imports PDF when text extraction fails', () async {
    service = ImportService(
      repo,
      getMeetingsDir: () async => meetingsDir,
      documentTextExtractor: (_) async => throw Exception('scanned PDF'),
    );
    final source = await makeSourceFile('scan.pdf');

    final meeting = await service.importFile(source.path);

    expect(meeting, isNotNull);
    expect(meeting!.type, MeetingType.document);
    expect(meeting.rawTranscript, isNull);
    expect(repo.saved.single.rawTranscript, isNull);
  });

  test('returns null for unsupported extension', () async {
    final source = await makeSourceFile('notes.docx');
    final meeting = await service.importFile(source.path);
    expect(meeting, isNull);
    expect(repo.saved, isEmpty);
  });

  test('all supported audio extensions are accepted', () async {
    for (final ext in ['mp3', 'wav', 'flac', 'aac', 'ogg', 'webm']) {
      final source = await makeSourceFile('file.$ext');
      final meeting = await service.importFile(source.path);
      expect(meeting, isNotNull, reason: 'Expected $ext to be accepted');
    }
  });

  test('copied file is placed inside meetingsDir', () async {
    final source = await makeSourceFile('talk.mp3');
    final meeting = await service.importFile(source.path);
    expect(p.dirname(meeting!.audioPath), equals(meetingsDir.path));
  });

  test('each import gets a unique id and path', () async {
    final s1 = await makeSourceFile('a.mp3');
    final s2 = await makeSourceFile('b.mp3');
    final m1 = await service.importFile(s1.path);
    final m2 = await service.importFile(s2.path);
    expect(m1!.id, isNot(equals(m2!.id)));
    expect(m1.audioPath, isNot(equals(m2.audioPath)));
  });
}

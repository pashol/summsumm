import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:summsumm/models/chat_session.dart';
import 'package:summsumm/models/chat_message.dart';
import 'package:summsumm/services/chat_repository.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String _tempDir = Directory.systemTemp.createTempSync().path;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempDir;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  late ChatRepository repository;

  setUp(() {
    repository = ChatRepository();
  });

  tearDown(() async {
    final dir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    final chatsDir = Directory('$dir/ask_library_chats');
    if (await chatsDir.exists()) {
      await chatsDir.delete(recursive: true);
    }
  });

  test('save and load chat session', () async {
    final createdAt = DateTime(2025, 6, 1, 12, 0);
    final updatedAt = DateTime(2025, 6, 1, 13, 0);
    final session = ChatSession(
      id: 'test-1',
      title: 'Test Chat',
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: [
        const ChatMessage(role: 'user', content: 'Hello'),
        const ChatMessage(role: 'assistant', content: 'Hi there'),
      ],
      isArchived: true,
    );

    await repository.save(session);
    final loaded = await repository.loadById('test-1');
    
    expect(loaded, isNotNull);
    expect(loaded!.id, 'test-1');
    expect(loaded.title, 'Test Chat');
    expect(loaded.createdAt, createdAt.toUtc());
    expect(loaded.updatedAt, updatedAt.toUtc());
    expect(loaded.messages.length, 2);
    expect(loaded.messages[0].role, 'user');
    expect(loaded.messages[0].content, 'Hello');
    expect(loaded.messages[1].role, 'assistant');
    expect(loaded.messages[1].content, 'Hi there');
    expect(loaded.isArchived, true);
  });

  test('delete removes chat session', () async {
    final session = ChatSession(
      id: 'delete-test',
      title: 'To Delete',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );

    await repository.save(session);
    await repository.delete('delete-test');
    final loaded = await repository.loadById('delete-test');
    expect(loaded, isNull);
  });

  test('loadAll sorts by updatedAt descending', () async {
    final session1 = ChatSession(
      id: 'old',
      title: 'Old',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [],
    );
    final session2 = ChatSession(
      id: 'new',
      title: 'New',
      createdAt: DateTime(2025, 1, 2),
      updatedAt: DateTime(2025, 1, 2),
      messages: [],
    );

    await repository.save(session1);
    await repository.save(session2);
    final all = await repository.loadAll();
    
    expect(all[0].id, 'new');
    expect(all[1].id, 'old');
  });

  test('loadAll skips corrupt JSON files', () async {
    final session = ChatSession(
      id: 'valid',
      title: 'Valid',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [],
    );
    await repository.save(session);

    final dir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    final chatsDir = Directory('$dir/ask_library_chats');
    final corruptFile = File('${chatsDir.path}/corrupt.json');
    await corruptFile.writeAsString('this is not json');

    final all = await repository.loadAll();
    expect(all.length, 1);
    expect(all[0].id, 'valid');
  });

  test('loadAll returns empty list for empty directory', () async {
    final all = await repository.loadAll();
    expect(all, isEmpty);
  });

  test('save overwrites existing file', () async {
    final session = ChatSession(
      id: 'overwrite-test',
      title: 'Original',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [const ChatMessage(role: 'user', content: 'Original')],
    );

    await repository.save(session);

    final updated = session.copyWith(
      title: 'Updated',
      messages: [const ChatMessage(role: 'user', content: 'Updated')],
      updatedAt: DateTime(2025, 1, 2),
    );

    await repository.save(updated);
    final loaded = await repository.loadById('overwrite-test');

    expect(loaded, isNotNull);
    expect(loaded!.title, 'Updated');
    expect(loaded.messages[0].content, 'Updated');
    expect(loaded.updatedAt, DateTime(2025, 1, 2).toUtc());
  });
}

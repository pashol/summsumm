import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/chat_session.dart';

class ChatRepository {
  static const _chatsDirName = 'ask_library_chats';

  Future<Directory> _chatsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final chatsDir = Directory(path.join(docsDir.path, _chatsDirName));
    await chatsDir.create(recursive: true);
    return chatsDir;
  }

  Future<List<ChatSession>> loadAll() async {
    try {
      final dir = await _chatsDir();
      final jsonFiles = dir.listSync().where((e) => e.path.endsWith('.json'));
      final sessions = <ChatSession>[];

      for (final file in jsonFiles) {
        try {
          final json = jsonDecode(
            File(file.path).readAsStringSync(),
          ) as Map<String, dynamic>;
          sessions.add(ChatSession.fromJson(json));
        } catch (e, st) {
          debugPrint('Error loading chat from ${file.path}: $e\n$st');
        }
      }

      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (e, st) {
      debugPrint('Error in loadAll(): $e\n$st');
      return [];
    }
  }

  Future<ChatSession?> loadById(String id) async {
    try {
      final dir = await _chatsDir();
      final file = File(path.join(dir.path, '$id.json'));
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ChatSession.fromJson(json);
    } catch (e, st) {
      debugPrint('Error loading chat $id: $e\n$st');
      return null;
    }
  }

  Future<void> save(ChatSession session) async {
    final dir = await _chatsDir();
    final jsonFile = File(path.join(dir.path, '${session.id}.json'));
    final tempFile = File('${jsonFile.path}.tmp');
    tempFile.writeAsStringSync(jsonEncode(session.toJson()));
    await tempFile.rename(jsonFile.path);
  }

  Future<void> delete(String id) async {
    final dir = await _chatsDir();
    final file = File(path.join(dir.path, '$id.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

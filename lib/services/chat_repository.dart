import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/chat_session.dart';

class ChatRepository {
  static const _chatsDirName = 'ask_library_chats';

  Future<Directory> _chatsDir() async {
    debugPrint('ChatRepository _chatsDir() called');
    final docsDir = await getApplicationDocumentsDirectory();
    debugPrint('ChatRepository _chatsDir() got docsDir: ${docsDir.path}');
    final chatsDir = Directory(path.join(docsDir.path, _chatsDirName));
    await chatsDir.create(recursive: true);
    return chatsDir;
  }

  Future<List<ChatSession>> loadAll() async {
    try {
      final dir = await _chatsDir();
      final jsonFiles = dir.listSync().where((e) => e.path.endsWith('.json'));
      debugPrint('ChatRepository loadAll: found ${jsonFiles.length} json files');
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

      debugPrint('ChatRepository loadAll: loaded ${sessions.length} sessions, sorting...');
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      debugPrint('ChatRepository loadAll: done, returning ${sessions.length} sessions');
      return sessions;
    } catch (e, st) {
      debugPrint('Error in ChatRepository loadAll(): $e\n$st');
      rethrow;
    }
  }

  Future<ChatSession?> loadById(String id) async {
    try {
      final dir = await _chatsDir();
      final file = File(path.join(dir.path, '$id.json'));
      if (!await file.exists()) {
        debugPrint('ChatRepository loadById: file not found for $id');
        return null;
      }

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      debugPrint('ChatRepository loadById: loaded session $id');
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
    try {
      await tempFile.writeAsString(jsonEncode(session.toJson()));
      await tempFile.rename(jsonFile.path);
      debugPrint('ChatRepository save: saved session ${session.id}');
    } catch (e, st) {
      debugPrint('Error in ChatRepository save(): $e\n$st');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final dir = await _chatsDir();
    final file = File(path.join(dir.path, '$id.json'));
    if (await file.exists()) {
      await file.delete();
      debugPrint('ChatRepository delete: deleted session $id');
    } else {
      debugPrint('ChatRepository delete: file not found for $id');
    }
  }
}

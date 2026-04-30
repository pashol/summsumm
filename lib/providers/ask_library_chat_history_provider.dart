import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import 'chat_repository_provider.dart';

class AskLibraryChatHistoryNotifier extends StateNotifier<List<ChatSession>> {
  final Ref _ref;

  AskLibraryChatHistoryNotifier(this._ref) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final repository = _ref.read(chatRepositoryProvider);
    final sessions = await repository.loadAll();
    state = sessions;
  }

  Future<void> refresh() async {
    await _loadHistory();
  }

  Future<void> deleteSession(String id) async {
    final repository = _ref.read(chatRepositoryProvider);
    await repository.delete(id);
    await refresh();
  }

  Future<void> renameSession(String id, String newTitle) async {
    final repository = _ref.read(chatRepositoryProvider);
    final session = await repository.loadById(id);
    if (session == null) return;

    final updated = session.copyWith(title: newTitle);
    await repository.save(updated);
    await refresh();
  }
}

final askLibraryChatHistoryProvider =
    StateNotifierProvider<AskLibraryChatHistoryNotifier, List<ChatSession>>(
  (ref) => AskLibraryChatHistoryNotifier(ref),
);

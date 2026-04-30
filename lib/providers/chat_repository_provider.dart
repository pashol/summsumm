import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

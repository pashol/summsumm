import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_llm_service.dart';

final localLlmServiceProvider = Provider<LocalLlmService>((ref) {
  final service = LocalLlmService();
  ref.onDispose(() => service.close());
  return service;
});

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/ai_model.dart';
import '../services/ai_service.dart';

part 'models_provider.g.dart';

@Riverpod(keepAlive: true)
AiService aiService(AiServiceRef ref) => AiService();

@riverpod
Future<List<AIModel>> openRouterModels(
  OpenRouterModelsRef ref,
  String apiKey,
) {
  return ref.watch(aiServiceProvider).fetchOpenRouterModels(apiKey);
}

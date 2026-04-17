import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/voice_service.dart';

part 'voice_service_provider.g.dart';

@Riverpod(keepAlive: true)
VoiceService voiceService(VoiceServiceRef ref) {
  final service = VoiceService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
}

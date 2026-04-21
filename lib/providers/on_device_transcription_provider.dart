import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/on_device_transcription_service.dart';

final onDeviceTranscriptionServiceProvider = Provider<OnDeviceTranscriptionService>((ref) {
  final service = OnDeviceTranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

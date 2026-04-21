import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/model_download_manager.dart';

final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final manager = ModelDownloadManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final modelDownloadProgressProvider = StreamProvider<DownloadProgress>((ref) {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.progressStream;
});

final modelAvailabilityProvider = FutureProvider.family<bool, ModelSize>((ref, size) async {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.isModelAvailable(size);
});

final speakerModelAvailabilityProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.isSpeakerModelAvailable();
});

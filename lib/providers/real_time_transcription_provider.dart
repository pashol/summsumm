import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/services/real_time_transcription_service.dart';

final realTimeTranscriptionServiceProvider = Provider<RealTimeTranscriptionService>((ref) {
  final service = RealTimeTranscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final realTimeTranscriptStreamProvider = StreamProvider<TranscriptSegment>((ref) {
  final service = ref.watch(realTimeTranscriptionServiceProvider);
  return service.transcriptStream;
});

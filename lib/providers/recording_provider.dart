import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/recording_service.dart';

final recordingServiceProvider = Provider<RecordingService>((ref) {
  return RecordingService();
});
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/transcription_model_download_plan.dart';

void main() {
  group('transcriptionModelDownloadPlan', () {
    test('does not include diarization models when diarization is disabled',
        () {
      final plan = transcriptionModelDownloadPlan(
        enableRealTimeTranscription: false,
        onDeviceDiarization: false,
      );

      expect(plan.downloadStreamingModel, false);
      expect(plan.downloadDiarizationModels, false);
    });

    test('includes diarization models only when diarization is enabled', () {
      final plan = transcriptionModelDownloadPlan(
        enableRealTimeTranscription: false,
        onDeviceDiarization: true,
      );

      expect(plan.downloadStreamingModel, false);
      expect(plan.downloadDiarizationModels, true);
    });

    test('includes streaming model only when live transcription is enabled',
        () {
      final plan = transcriptionModelDownloadPlan(
        enableRealTimeTranscription: true,
        onDeviceDiarization: false,
      );

      expect(plan.downloadStreamingModel, true);
      expect(plan.downloadDiarizationModels, false);
    });
  });
}

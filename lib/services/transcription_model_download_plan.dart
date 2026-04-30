class TranscriptionModelDownloadPlan {
  final bool downloadStreamingModel;
  final bool downloadDiarizationModels;

  const TranscriptionModelDownloadPlan({
    required this.downloadStreamingModel,
    required this.downloadDiarizationModels,
  });
}

TranscriptionModelDownloadPlan transcriptionModelDownloadPlan({
  required bool enableRealTimeTranscription,
  required bool onDeviceDiarization,
}) {
  return TranscriptionModelDownloadPlan(
    downloadStreamingModel: enableRealTimeTranscription,
    downloadDiarizationModels: onDeviceDiarization,
  );
}

String transcriptionStatusLabel(String? status) {
  final trimmed = status?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return 'Starting transcription...';
}

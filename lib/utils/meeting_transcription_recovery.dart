import 'package:summsumm/models/meeting.dart';

Meeting recoverStaleTranscription(Meeting meeting) {
  if (meeting.status != MeetingStatus.transcribing) return meeting;

  final status = meeting.transcriptionStatus?.trim();
  if (status != null && status.isNotEmpty) return meeting;

  return meeting.copyWith(
    status: MeetingStatus.failed,
    lastError: 'Transcription was interrupted. Please retry.',
    clearTranscriptionStatus: true,
    clearTranscriptionProgress: true,
  );
}

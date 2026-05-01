import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/utils/meeting_transcription_recovery.dart';

void main() {
  Meeting meeting({
    MeetingStatus status = MeetingStatus.recorded,
    String? transcriptionStatus,
  }) {
    return Meeting(
      id: 'm1',
      createdAt: DateTime(2026),
      durationSec: 1,
      audioPath: '/tmp/audio.m4a',
      title: 'Audio',
      status: status,
      transcriptionStatus: transcriptionStatus,
    );
  }

  test('fails transcribing meetings without a concrete status', () {
    final recovered = recoverStaleTranscription(
      meeting(status: MeetingStatus.transcribing),
    );

    expect(recovered.status, MeetingStatus.failed);
    expect(recovered.lastError, contains('interrupted'));
    expect(recovered.transcriptionStatus, isNull);
  });

  test('keeps active transcribing meetings with a concrete status', () {
    final active = meeting(
      status: MeetingStatus.transcribing,
      transcriptionStatus: 'Loading models...',
    );

    expect(recoverStaleTranscription(active), same(active));
  });
}

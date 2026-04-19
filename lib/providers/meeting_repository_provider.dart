import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/meeting_repository.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository();
});

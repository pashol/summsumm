import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/meeting_repository.dart';
import 'package:summsumm/utils/meeting_transcription_recovery.dart';

final meetingLibraryProvider =
    AsyncNotifierProvider<MeetingLibraryNotifier, List<Meeting>>(
      MeetingLibraryNotifier.new,
    );

class MeetingLibraryNotifier extends AsyncNotifier<List<Meeting>> {
  @override
  Future<List<Meeting>> build() async {
    debugPrint('MeetingLibraryNotifier.build() called');
    try {
      final all = await _loadRecoveredMeetings();
      debugPrint(
        'MeetingLibraryNotifier.build() returning ${all.length} meetings',
      );
      return all.where((m) => !m.archived).toList();
    } catch (e, st) {
      debugPrint('MeetingLibraryNotifier.build() ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final all = await _loadRecoveredMeetings();
      return all.where((m) => !m.archived).toList();
    });
  }

  Future<List<Meeting>> _loadRecoveredMeetings() async {
    final repository = MeetingRepository();
    final all = await repository.loadAll();
    final recovered = <Meeting>[];
    for (final meeting in all) {
      final next = recoverStaleTranscription(meeting);
      if (!identical(next, meeting)) {
        await repository.save(next);
      }
      recovered.add(next);
    }
    return recovered;
  }
}

final archivedMeetingsProvider =
    AsyncNotifierProvider<ArchivedMeetingsNotifier, List<Meeting>>(
      ArchivedMeetingsNotifier.new,
    );

class ArchivedMeetingsNotifier extends AsyncNotifier<List<Meeting>> {
  @override
  Future<List<Meeting>> build() async {
    debugPrint('ArchivedMeetingsNotifier.build() called');
    try {
      final all = await MeetingRepository().loadAll();
      final recovered = all.map(recoverStaleTranscription).toList();
      debugPrint(
        'ArchivedMeetingsNotifier.build() returning ${all.length} meetings',
      );
      return recovered.where((m) => m.archived).toList();
    } catch (e, st) {
      debugPrint('ArchivedMeetingsNotifier.build() ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final all = await MeetingRepository().loadAll();
      final recovered = all.map(recoverStaleTranscription).toList();
      return recovered.where((m) => m.archived).toList();
    });
  }
}

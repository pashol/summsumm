import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/services/meeting_repository.dart';

final meetingLibraryProvider =
    AsyncNotifierProvider<MeetingLibraryNotifier, List<Meeting>>(
  MeetingLibraryNotifier.new,
);

class MeetingLibraryNotifier extends AsyncNotifier<List<Meeting>> {
  @override
  Future<List<Meeting>> build() async {
    debugPrint('MeetingLibraryNotifier.build() called');
    try {
      final all = await MeetingRepository().loadAll();
      debugPrint('MeetingLibraryNotifier.build() returning ${all.length} meetings');
      return all.where((m) => !m.archived).toList();
    } catch (e, st) {
      debugPrint('MeetingLibraryNotifier.build() ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final all = await MeetingRepository().loadAll();
      return all.where((m) => !m.archived).toList();
    });
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
      debugPrint('ArchivedMeetingsNotifier.build() returning ${all.length} meetings');
      return all.where((m) => m.archived).toList();
    } catch (e, st) {
      debugPrint('ArchivedMeetingsNotifier.build() ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final all = await MeetingRepository().loadAll();
      return all.where((m) => m.archived).toList();
    });
  }
}

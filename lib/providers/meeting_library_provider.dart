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
    final all = await MeetingRepository().loadAll();
    return all.where((m) => !m.archived).toList();
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
    final all = await MeetingRepository().loadAll();
    return all.where((m) => m.archived).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final all = await MeetingRepository().loadAll();
      return all.where((m) => m.archived).toList();
    });
  }
}

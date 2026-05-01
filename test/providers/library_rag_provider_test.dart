import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/app_settings.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/models/meeting.dart';
import 'package:summsumm/providers/meeting_library_provider.dart';
import 'package:summsumm/providers/library_rag_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';
import 'package:summsumm/services/library_rag_metadata_store.dart';
import 'package:summsumm/services/library_rag_repository.dart';
import 'package:summsumm/services/library_rag_service.dart';

class _EnabledSettings extends Settings {
  @override
  AppSettings build() =>
      const AppSettings.defaults().copyWith(localLibraryChatEnabled: true);

  @override
  Future<void> setLocalLibraryChatEnabled(bool enabled) async {
    state = state.copyWith(localLibraryChatEnabled: enabled);
  }
}

class _LoadedMeetings extends MeetingLibraryNotifier {
  @override
  Future<List<Meeting>> build() async => [_meeting];
}

class _MutableMeetings extends MeetingLibraryNotifier {
  List<Meeting> meetings = [_meeting];

  @override
  Future<List<Meeting>> build() async => meetings;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(meetings);
  }
}

class _LoadedDocuments extends MeetingLibraryNotifier {
  @override
  Future<List<Meeting>> build() async => [_document];
}

class _MemoryMetadataStore extends LibraryRagMetadataStore {
  LibraryRagMetadata _metadata = const LibraryRagMetadata();

  @override
  Future<LibraryRagMetadata> load() async => _metadata;

  @override
  Future<void> save(LibraryRagMetadata metadata) async {
    _metadata = metadata;
  }

  @override
  Future<void> clear() async {
    _metadata = const LibraryRagMetadata();
  }
}

final _meeting = Meeting(
  id: 'meeting-1',
  createdAt: DateTime.utc(2026, 4, 29),
  durationSec: 60,
  audioPath: '/tmp/meeting-1.m4a',
  title: 'Meeting 1',
  rawTranscript: 'alpha beta gamma',
  status: MeetingStatus.transcribed,
);

final _document = Meeting(
  id: 'document-1',
  createdAt: DateTime.utc(2026, 4, 29),
  durationSec: 0,
  audioPath: '/tmp/document-1.pdf',
  title: 'Document 1',
  status: MeetingStatus.done,
  type: MeetingType.document,
);

void main() {
  test('initial state is disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(libraryRagSetupProvider);

    expect(state.readiness, LibraryRagReadiness.disabled);
  });

  test(
    'refreshReadiness prepares estimate when enabled library is not indexed',
    () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_EnabledSettings.new),
          meetingLibraryProvider.overrideWith(_LoadedMeetings.new),
          libraryRagRepositoryProvider.overrideWithValue(
            LibraryRagRepository(
              ragService: LibraryRagService(client: FakeLibraryRagClient()),
              metadataStore: _MemoryMetadataStore(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(libraryRagSetupProvider.notifier).refreshReadiness();

      final state = container.read(libraryRagSetupProvider);
      expect(state.readiness, LibraryRagReadiness.enabledNotIndexed);
      expect(state.estimate, isNotNull);
      expect(state.estimate!.meetingCount, 1);
      expect(state.estimate!.hasEligibleContent, isTrue);
    },
  );

  test('loadEstimate surfaces estimate failures in provider state', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_EnabledSettings.new),
        meetingLibraryProvider.overrideWith(_LoadedDocuments.new),
        libraryRagRepositoryProvider.overrideWithValue(
          LibraryRagRepository(
            ragService: LibraryRagService(client: FakeLibraryRagClient()),
            metadataStore: _MemoryMetadataStore(),
            documentTextExtractor: (_) async =>
                throw Exception('extract failed'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(libraryRagSetupProvider.notifier).loadEstimate();

    final state = container.read(libraryRagSetupProvider);
    expect(state.readiness, LibraryRagReadiness.failed);
    expect(state.error, contains('extract failed'));
  });

  test('refreshes readiness when the meeting library changes', () async {
    final store = _MemoryMetadataStore();
    final repository = LibraryRagRepository(
      ragService: LibraryRagService(client: FakeLibraryRagClient()),
      metadataStore: store,
    );
    await repository.indexAll([_meeting]);
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_EnabledSettings.new),
        meetingLibraryProvider.overrideWith(_MutableMeetings.new),
        libraryRagRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(libraryRagSetupProvider.notifier).refreshReadiness();
    expect(
      container.read(libraryRagSetupProvider).readiness,
      LibraryRagReadiness.ready,
    );

    final meetings =
        container.read(meetingLibraryProvider.notifier) as _MutableMeetings;
    meetings.meetings = [_meeting, _meeting.copyWith(id: 'meeting-2')];
    await meetings.refresh();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(libraryRagSetupProvider).readiness,
      LibraryRagReadiness.stale,
    );
  });
}

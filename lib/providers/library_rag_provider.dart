import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_rag.dart';
import '../providers/meeting_library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/library_rag_metadata_store.dart';
import '../services/library_rag_repository.dart';
import '../services/library_rag_service.dart';

final libraryRagServiceProvider = Provider<LibraryRagService>((ref) {
  return LibraryRagService();
});

final libraryRagMetadataStoreProvider =
    Provider<LibraryRagMetadataStore>((ref) {
  return LibraryRagMetadataStore();
});

final libraryRagRepositoryProvider = Provider<LibraryRagRepository>((ref) {
  return LibraryRagRepository(
    ragService: ref.watch(libraryRagServiceProvider),
    metadataStore: ref.watch(libraryRagMetadataStoreProvider),
  );
});

class LibraryRagSetupState {
  final LibraryRagReadiness readiness;
  final LibraryIndexEstimate? estimate;
  final LibraryIndexProgress? progress;
  final String? error;

  const LibraryRagSetupState({
    this.readiness = LibraryRagReadiness.disabled,
    this.estimate,
    this.progress,
    this.error,
  });

  LibraryRagSetupState copyWith({
    LibraryRagReadiness? readiness,
    LibraryIndexEstimate? estimate,
    LibraryIndexProgress? progress,
    String? error,
    bool clearError = false,
  }) {
    return LibraryRagSetupState(
      readiness: readiness ?? this.readiness,
      estimate: estimate ?? this.estimate,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LibraryRagSetupNotifier extends Notifier<LibraryRagSetupState> {
  @override
  LibraryRagSetupState build() {
    final enabled = ref.watch(settingsProvider).localLibraryChatEnabled;
    if (!enabled) return const LibraryRagSetupState();
    return const LibraryRagSetupState(
      readiness: LibraryRagReadiness.enabledNotIndexed,
    );
  }

  Future<void> loadEstimate() async {
    try {
      final library = await ref.read(meetingLibraryProvider.future);
      final estimate =
          await ref.read(libraryRagRepositoryProvider).estimate(library);
      state = state.copyWith(estimate: estimate, clearError: true);
    } catch (e, st) {
      debugPrint('loadEstimate failed: $e\n$st');
      state = state.copyWith(
        readiness: LibraryRagReadiness.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> enableAndEstimate() async {
    await ref.read(settingsProvider.notifier).setLocalLibraryChatEnabled(true);
    state = state.copyWith(
      readiness: LibraryRagReadiness.enabledNotIndexed,
      clearError: true,
    );
    await loadEstimate();
  }

  Future<void> indexLibrary() async {
    await _performSync(preserveStaleOnError: false);
  }

  Future<void> refreshReadiness() async {
    if (state.readiness == LibraryRagReadiness.indexing) return;

    final enabled = ref.read(settingsProvider).localLibraryChatEnabled;
    if (!enabled) {
      state = const LibraryRagSetupState();
      return;
    }
    try {
      final library = await ref.read(meetingLibraryProvider.future);
      final inspection =
          await ref.read(libraryRagRepositoryProvider).inspectIndex(library);
      if (inspection.status == LibraryIndexInspectionStatus.notIndexed) {
        state = state.copyWith(
          readiness: LibraryRagReadiness.enabledNotIndexed,
          clearError: true,
        );
        await loadEstimate();
        return;
      }
      state = state.copyWith(
        readiness: switch (inspection.status) {
          LibraryIndexInspectionStatus.notIndexed =>
            LibraryRagReadiness.enabledNotIndexed,
          LibraryIndexInspectionStatus.ready => LibraryRagReadiness.ready,
          LibraryIndexInspectionStatus.stale => LibraryRagReadiness.stale,
        },
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('refreshReadiness failed: $e\n$st');
      state = state.copyWith(
        readiness: LibraryRagReadiness.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> updateIndex() async {
    await _performSync(preserveStaleOnError: true);
  }

  Future<void> _performSync({required bool preserveStaleOnError}) async {
    final previousReadiness = state.readiness;
    final library = await ref.read(meetingLibraryProvider.future);
    state = state.copyWith(
      readiness: LibraryRagReadiness.indexing,
      clearError: true,
    );
    try {
      await ref.read(libraryRagRepositoryProvider).syncLibrary(
        library,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(readiness: LibraryRagReadiness.ready);
    } catch (e, st) {
      debugPrint('updateIndex failed: $e\n$st');
      state = state.copyWith(
        readiness: preserveStaleOnError &&
                previousReadiness == LibraryRagReadiness.stale
            ? LibraryRagReadiness.stale
            : LibraryRagReadiness.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> disable() async {
    await ref.read(settingsProvider.notifier).setLocalLibraryChatEnabled(false);
    state = const LibraryRagSetupState();
  }
}

final libraryRagSetupProvider =
    NotifierProvider<LibraryRagSetupNotifier, LibraryRagSetupState>(
  LibraryRagSetupNotifier.new,
);

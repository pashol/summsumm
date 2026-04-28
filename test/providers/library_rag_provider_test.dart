import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/models/library_rag.dart';
import 'package:summsumm/providers/library_rag_provider.dart';

void main() {
  test('initial state is disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(libraryRagSetupProvider);

    expect(state.readiness, LibraryRagReadiness.disabled);
  });
}

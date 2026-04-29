import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/library_rag_service.dart';

void main() {
  test('initialize is idempotent', () async {
    final client = FakeLibraryRagClient();
    final service = LibraryRagService(client: client);

    await service.initialize();
    await service.initialize();

    expect(client.initializeCalls, 1);
  });

  test('addSource delegates metadata and title', () async {
    final client = FakeLibraryRagClient();
    final service = LibraryRagService(client: client);

    final id = await service.addSource(
      text: 'hello world',
      title: 'Greeting',
      metadataJson: '{"id":"a"}',
    );

    expect(id, 1);
    expect(client.lastText, 'hello world');
    expect(client.lastName, 'Greeting');
    expect(client.lastMetadata, '{"id":"a"}');
  });
}

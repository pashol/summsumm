import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/library_rag.dart';

class LibraryRagMetadataStore {
  final Future<Directory> Function()? _getBaseDir;

  LibraryRagMetadataStore({Future<Directory> Function()? getBaseDir})
      : _getBaseDir = getBaseDir;

  Future<File> _file() async {
    final baseDir = _getBaseDir == null
        ? await getApplicationDocumentsDirectory()
        : await _getBaseDir!();
    final dir = Directory(p.join(baseDir.path, 'rag'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'library_rag_metadata.json'));
  }

  Future<LibraryRagMetadata> load() async {
    final file = await _file();
    if (!await file.exists()) return const LibraryRagMetadata();
    try {
      return LibraryRagMetadata.fromJsonString(await file.readAsString());
    } catch (_) {
      return const LibraryRagMetadata();
    }
  }

  Future<void> save(LibraryRagMetadata metadata) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(metadata.toJsonString());
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

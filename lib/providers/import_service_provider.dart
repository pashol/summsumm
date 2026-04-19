import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/services/import_service.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.read(meetingRepositoryProvider));
});

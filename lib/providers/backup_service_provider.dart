import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/services/backup_service.dart';

import 'meeting_repository_provider.dart';
import 'settings_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final meetingRepository = ref.watch(meetingRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  
  return BackupService(
    meetingRepository: meetingRepository,
    secureStorage: secureStorage,
    getSettings: () => ref.read(settingsProvider),
    onSettingsImported: (settings) {
      ref.read(settingsProvider.notifier).persistSettingsDirect(settings);
    },
  );
});

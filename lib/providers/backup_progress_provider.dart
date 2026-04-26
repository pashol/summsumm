import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:summsumm/providers/backup_service_provider.dart';
import 'package:summsumm/services/backup_destination.dart';

enum BackupStatus { idle, running, completed, failed }

class BackupProgress {
  final BackupStatus status;
  final double progress;
  final String? filePath;
  final String? error;

  const BackupProgress({
    this.status = BackupStatus.idle,
    this.progress = 0,
    this.filePath,
    this.error,
  });

  BackupProgress copyWith({
    BackupStatus? status,
    double? progress,
    String? filePath,
    String? error,
  }) =>
      BackupProgress(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        filePath: filePath ?? this.filePath,
        error: error ?? this.error,
      );
}

class BackupProgressNotifier extends StateNotifier<BackupProgress> {
  final Ref _ref;
  static const _platform = MethodChannel('app.summsumm/intent');

  BackupProgressNotifier(this._ref) : super(const BackupProgress());

  Future<void> startExport({
    required String password,
    required bool includeSettings,
    required bool includeApiKeys,
    required bool includeMeetings,
    required bool includeAudio,
    required String filename,
    required bool saveToDevice,
  }) async {
    if (state.status == BackupStatus.running) return;

    state = const BackupProgress(status: BackupStatus.running, progress: 0);

    if (saveToDevice) {
      await _platform.invokeMethod('startBackupForeground');
    }

    try {
      _updateNotification(
        title: 'Creating backup',
        text: 'Collecting data...',
        progress: 10,
      );
      state = state.copyWith(progress: 0.1);

      final service = _ref.read(backupServiceProvider);

      if (!saveToDevice) {
        final tempDir = Directory.systemTemp.createTempSync('summsumm_backup_');
        final file = await service.export(
          password: password,
          includeSettings: includeSettings,
          includeApiKeys: includeApiKeys,
          includeMeetings: includeMeetings,
          includeAudio: includeAudio,
          filename: filename,
          outputDir: tempDir.path,
        );

        _updateNotification(
          title: 'Creating backup',
          text: 'Preparing to share...',
          progress: 90,
        );
        state = state.copyWith(progress: 0.9);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Summsumm Backup',
        );
      } else {
        _updateNotification(
          title: 'Creating backup',
          text: 'Processing data...',
          progress: 20,
        );
        state = state.copyWith(progress: 0.2);

        final tempDir = await BackupDestination.getTempBackupDir();
        final tempFile = await service.saveToFile(
          password: password,
          includeSettings: includeSettings,
          includeApiKeys: includeApiKeys,
          includeMeetings: includeMeetings,
          includeAudio: includeAudio,
          outputPath: p.join(tempDir, '$filename.summsumm'),
        );

        _updateNotification(
          title: 'Creating backup',
          text: 'Saving to Downloads...',
          progress: 60,
        );
        state = state.copyWith(progress: 0.6);

        final displayName = p.basename(tempFile.path);
        final publicUri = await BackupDestination.saveToPublicDownloads(
          sourcePath: tempFile.path,
          displayName: displayName,
        );

        // Clean up temp file
        try {
          await tempFile.delete();
        } catch (_) {}

        _updateNotification(
          title: 'Creating backup',
          text: 'Almost done...',
          progress: 90,
        );
        state = state.copyWith(progress: 0.9);

        await _platform.invokeMethod('showBackupComplete', {
          'filePath': publicUri,
          'displayName': displayName,
        });

        state = state.copyWith(
          status: BackupStatus.completed,
          progress: 1.0,
          filePath: publicUri,
        );
        return;
      }

      state = state.copyWith(
        status: BackupStatus.completed,
        progress: 1.0,
      );
    } catch (e) {
      if (saveToDevice) {
        await _platform.invokeMethod('showBackupError', {
          'errorMessage': e.toString(),
        });
      }
      state = state.copyWith(
        status: BackupStatus.failed,
        error: e.toString(),
      );
    }
  }

  void _updateNotification({
    required String title,
    required String text,
    required int progress,
  }) {
    _platform.invokeMethod('updateBackupProgress', {
      'title': title,
      'text': text,
      'progress': progress,
      'max': 100,
      'indeterminate': false,
    });
  }

  void reset() {
    state = const BackupProgress();
  }
}

final backupProgressProvider =
    StateNotifierProvider<BackupProgressNotifier, BackupProgress>(
  (ref) => BackupProgressNotifier(ref),
);

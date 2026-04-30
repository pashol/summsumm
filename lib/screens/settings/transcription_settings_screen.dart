import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/transcription_config.dart';
import '../../providers/model_download_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/processing_service.dart';
import '../../services/transcription_model_download_plan.dart';

class TranscriptionSettingsScreen extends ConsumerStatefulWidget {
  const TranscriptionSettingsScreen({super.key});

  @override
  ConsumerState<TranscriptionSettingsScreen> createState() =>
      _TranscriptionSettingsScreenState();
}

class _TranscriptionSettingsScreenState
    extends ConsumerState<TranscriptionSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device Transcription'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable on-device transcription
          SwitchListTile(
            title: const Text('Use on-device transcription'),
            subtitle: const Text('Transcribe offline without internet'),
            value: settings.transcriptionStrategy ==
                TranscriptionStrategy.onDevice,
            onChanged: (v) async {
              await notifier.setTranscriptionStrategy(
                v
                    ? TranscriptionStrategy.onDevice
                    : TranscriptionStrategy.cloud,
              );
            },
          ),

          SwitchListTile(
            title: Text(l10n.settingsShowExtractedPdfTextOnly),
            subtitle: Text(l10n.settingsShowExtractedPdfTextOnlySubtitle),
            value: settings.showExtractedPdfTextOnly,
            onChanged: notifier.setShowExtractedPdfTextOnly,
          ),
          // Model Management Section (only when on-device enabled)
          if (settings.transcriptionStrategy ==
              TranscriptionStrategy.onDevice) ...[
            const SizedBox(height: 16),
            Text(
              'Speech Recognition Models',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Download a model to use on-device transcription',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),

            // Download progress
            Consumer(
              builder: (context, ref, child) {
                final progressAsync = ref.watch(modelDownloadProgressProvider);
                return progressAsync.when(
                  data: (progress) {
                    if (progress.status == DownloadStatus.downloading) {
                      final modelName =
                          progress.modelSize?.name ?? progress.type.name;
                      return Column(
                        children: [
                          LinearProgressIndicator(value: progress.fraction),
                          const SizedBox(height: 4),
                          Text(
                              'Downloading $modelName model... ${(progress.fraction * 100).toStringAsFixed(0)}%'),
                          const SizedBox(height: 8),
                        ],
                      );
                    } else if (progress.status == DownloadStatus.extracting) {
                      final modelName =
                          progress.modelSize?.name ?? progress.type.name;
                      return Column(
                        children: [
                          const LinearProgressIndicator(),
                          const SizedBox(height: 4),
                          Text('Extracting $modelName model...'),
                          const SizedBox(height: 8),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

            Consumer(
              builder: (context, ref, child) {
                final downloadedAsync = ref.watch(downloadedModelsProvider);
                final progressAsync = ref.watch(modelDownloadProgressProvider);
                return downloadedAsync.when(
                  data: (downloaded) {
                    return Column(
                      children: downloaded.entries.map((entry) {
                        final size = entry.key;
                        final isDownloaded = entry.value;
                        final isSelected = size == settings.onDeviceModelSize;
                        final isActive = isDownloaded && isSelected;
                        final label = switch (size) {
                          ModelSize.tiny => 'Tiny',
                          ModelSize.base => 'Base',
                          ModelSize.small => 'Small',
                        };
                        final sizeLabel = switch (size) {
                          ModelSize.tiny => '~75MB',
                          ModelSize.base => '~150MB',
                          ModelSize.small => '~500MB',
                        };

                        // Check if this model is currently downloading
                        final isDownloading =
                            progressAsync.valueOrNull?.status ==
                                    DownloadStatus.downloading &&
                                progressAsync.valueOrNull?.modelSize == size;
                        final isExtracting =
                            progressAsync.valueOrNull?.status ==
                                    DownloadStatus.extracting &&
                                progressAsync.valueOrNull?.modelSize == size;
                        final isBusy = isDownloading || isExtracting;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: isActive
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : (isDownloaded
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.circle_outlined,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () =>
                                            notifier.setOnDeviceModelSize(size),
                                      )
                                    : (isBusy
                                        ? Icon(
                                            isExtracting
                                                ? Icons.archive
                                                : Icons.downloading,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          )
                                        : IconButton(
                                            icon: Icon(
                                              Icons.download,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            onPressed: () async {
                                              final confirmed =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Download Model'),
                                                  content: Text(
                                                      'Download $label model ($sizeLabel)?\n\nThis may use significant data on metered connections.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child: const Text(
                                                          'Download'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirmed == true) {
                                                final manager = ref.read(
                                                    modelDownloadManagerProvider);
                                                final scaffoldMessenger =
                                                    ScaffoldMessenger.of(
                                                        context);

                                                final plan =
                                                    transcriptionModelDownloadPlan(
                                                  enableRealTimeTranscription:
                                                      settings
                                                          .enableRealTimeTranscription,
                                                  onDeviceDiarization: settings
                                                      .onDeviceDiarization,
                                                );

                                                try {
                                                  await ProcessingService()
                                                      .start();
                                                  await manager
                                                      .downloadModel(size);
                                                  ref.invalidate(
                                                      downloadedModelsProvider);

                                                  if (plan.downloadStreamingModel &&
                                                      !await manager
                                                          .isStreamingModelAvailable(
                                                              'English')) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Downloading streaming model...')),
                                                    );
                                                    await manager
                                                        .downloadStreamingModel(
                                                            'English');
                                                  }

                                                  if (plan.downloadDiarizationModels &&
                                                      !await manager
                                                          .isSegmentationModelAvailable()) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Downloading speaker segmentation model...')),
                                                    );
                                                    await manager
                                                        .downloadSegmentationModel();
                                                  }

                                                  if (plan.downloadDiarizationModels &&
                                                      !await manager
                                                          .isEmbeddingModelAvailable()) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Downloading speaker embedding model...')),
                                                    );
                                                    await manager
                                                        .downloadEmbeddingModel();
                                                  }

                                                  scaffoldMessenger
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'All models downloaded successfully!'),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                } catch (e) {
                                                  scaffoldMessenger
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Download failed: $e'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                } finally {
                                                  await ProcessingService()
                                                      .stop();
                                                  ref.invalidate(
                                                      downloadedModelsProvider);
                                                }
                                              }
                                            },
                                          ))),
                            title: Text('$label ($sizeLabel)'),
                            subtitle: isActive
                                ? const Text('Selected',
                                    style: TextStyle(color: Colors.green))
                                : (isBusy
                                    ? Text(
                                        isExtracting
                                            ? 'Extracting...'
                                            : 'Downloading...',
                                        style:
                                            const TextStyle(color: Colors.blue))
                                    : null),
                            trailing: isBusy
                                ? IconButton(
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.orange),
                                    onPressed: () {
                                      ref
                                          .read(modelDownloadManagerProvider)
                                          .cancelDownload();
                                      ref.invalidate(downloadedModelsProvider);
                                    },
                                  )
                                : (isDownloaded
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Model'),
                                              content:
                                                  Text('Delete $label model?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            final manager = ref.read(
                                                modelDownloadManagerProvider);
                                            await manager.deleteModel(size);
                                            ref.invalidate(
                                                downloadedModelsProvider);
                                          }
                                        },
                                      )
                                    : null),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Error loading model info'),
                );
              },
            ),

            const SizedBox(height: 16),

            // Live transcription toggle
            SwitchListTile(
              title: const Text('Live transcription'),
              subtitle: const Text('Transcribe while recording'),
              value: settings.enableRealTimeTranscription,
              onChanged: (v) async {
                if (v && settings.language == 'German') {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('English Model Only'),
                      content: const Text(
                        'Live transcription uses an English model. German speech will be transcribed with limited accuracy. Use cloud transcription for German.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                await notifier.setEnableRealTimeTranscription(v);
              },
            ),

            // Diarization toggle
            SwitchListTile(
              title: const Text('Speaker diarization'),
              subtitle: const Text('Identify different speakers'),
              value: settings.onDeviceDiarization,
              onChanged: (v) => notifier.setOnDeviceDiarization(v),
            ),
          ],
        ],
      ),
    );
  }
}

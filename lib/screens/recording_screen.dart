import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/models/transcription_config.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/real_time_transcription_provider.dart';
import 'package:summsumm/providers/recording_provider.dart';
import 'package:summsumm/providers/settings_provider.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final String _title =
      'Meeting ${DateTime.now().toLocal().toString().split(' ')[0]}';
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _liveTranscriptionEnabled = false;
  final List<String> _liveTranscriptSegments = [];
  StreamSubscription<TranscriptSegment>? _transcriptSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;

  @override
  void dispose() {
    _timer?.cancel();
    _transcriptSubscription?.cancel();
    _audioSubscription?.cancel();
    if (_isRecording) _stopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDuration(_elapsedSeconds),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 20),
            _isRecording
                ? ElevatedButton(
                    onPressed: _stopRecording,
                    child: Text(l10n.stopButton),
                  )
                : ElevatedButton(
                    onPressed: _startRecording,
                    child: Text(l10n.startButton),
                  ),
            if (_liveTranscriptionEnabled) ...[
              const SizedBox(height: 12),
              _buildLiveIndicator(),
              if (_liveTranscriptSegments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _liveTranscriptSegments.join(' '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recordingMicPermission)),
        );
      }
      return;
    }

    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationPermission)),
        );
      }
      return;
    }

    final settings = ref.read(settingsProvider);
    final isOnDevice = settings.transcriptionStrategy == TranscriptionStrategy.onDevice;
    var liveTranscription = settings.enableRealTimeTranscription;

    // Ask user if they want live transcription for this recording
    if (isOnDevice && !liveTranscription) {
      final wantLive = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = AppLocalizations.of(dialogContext)!;
          return AlertDialog(
            title: Text(dialogL10n.liveTranscriptionTitle),
            content: Text(dialogL10n.liveTranscriptionPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogL10n.liveTranscriptionNo),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogL10n.liveTranscriptionYes),
              ),
            ],
          );
        },
      );
      liveTranscription = wantLive ?? false;
    }

    try {
      final service = ref.read(recordingServiceProvider);
      await service.startRecording(_title, liveTranscription: liveTranscription);

      // Start live transcription if enabled
      if (liveTranscription) {
        final success = await _startLiveTranscription();
        if (!success) {
          liveTranscription = false;
        }
      }

      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsedSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recordingFailedStart(e.toString()))),
        );
      }
    }
  }

  Future<bool> _startLiveTranscription() async {
    final settings = ref.read(settingsProvider);
    final service = ref.read(realTimeTranscriptionServiceProvider);
    final recordingService = ref.read(recordingServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    try {
      await service.start(
        language: settings.streamingModelLanguage,
      );

      _transcriptSubscription = service.transcriptStream.listen((segment) {
        if (mounted) {
          setState(() {
            if (segment.isFinal) {
              _liveTranscriptSegments.add(segment.text);
            }
          });
        }
      });

      final audioStream = recordingService.audioStream;
      if (audioStream != null) {
        _audioSubscription = audioStream.listen((data) {
          service.onAudioData(data);
        });
      }

      setState(() {
        _liveTranscriptionEnabled = true;
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.liveTranscriptionFailed(e.toString()))),
        );
      }
      return false;
    }
  }

  Widget _buildLiveIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colorScheme.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.liveIndicator,
          style: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.bold,
            fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
          ),
        ),
      ],
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // Stop live transcription
    if (_liveTranscriptionEnabled) {
      await _transcriptSubscription?.cancel();
      _transcriptSubscription = null;
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      final service = ref.read(realTimeTranscriptionServiceProvider);
      await service.stop();
      setState(() {
        _liveTranscriptionEnabled = false;
      });
    }

    _timer?.cancel();
    _timer = null;
    setState(() => _isRecording = false);

    final service = ref.read(recordingServiceProvider);
    final meeting = await service.stopRecording(_elapsedSeconds);

    final repository = ref.read(meetingRepositoryProvider);
    await repository.save(meeting);
    if (mounted) Navigator.pop(context);
  }
}

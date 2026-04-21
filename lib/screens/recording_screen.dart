import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:summsumm/providers/meeting_repository_provider.dart';
import 'package:summsumm/providers/recording_provider.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
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
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recordingMicPermission)),
        );
      }
      return;
    }
    try {
      final service = ref.read(recordingServiceProvider);
      await service.startRecording(_title);
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

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
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

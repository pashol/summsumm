import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';

class AudioPlayerService {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isInitialized = false;
  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 200));
    _isInitialized = true;

    // Listen to progress updates from the player
    _progressSubscription = _player.onProgress?.listen((event) {
      _currentPosition = event.position;
      _currentDuration = event.duration;
      _positionController.add(_currentPosition);
      _durationController.add(_currentDuration);
    });
  }

  Future<void> play(String path) async {
    await init();
    final duration = await _player.startPlayer(
      fromURI: path,
      whenFinished: () {
        _isPlayingController.add(false);
        _currentPosition = Duration.zero;
        _positionController.add(_currentPosition);
      },
    );
    if (duration != null && duration > Duration.zero) {
      _currentDuration = duration;
      _durationController.add(_currentDuration);
    }
    _isPlayingController.add(true);
  }

  Future<void> pause() async {
    await _player.pausePlayer();
    _isPlayingController.add(false);
  }

  Future<void> resume() async {
    await _player.resumePlayer();
    _isPlayingController.add(true);
  }

  Future<void> stop() async {
    await _player.stopPlayer();
    _isPlayingController.add(false);
    _currentPosition = Duration.zero;
    _positionController.add(_currentPosition);
  }

  Future<void> seek(Duration position) async {
    await _player.seekToPlayer(position);
    _currentPosition = position;
    _positionController.add(_currentPosition);
  }

  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    await _player.closePlayer();
    await _positionController.close();
    await _durationController.close();
    await _isPlayingController.close();
  }
}

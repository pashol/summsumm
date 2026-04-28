class AudioSeekState {
  bool _isSeeking = false;
  double? _dragValue;

  bool get isSeeking => _isSeeking;
  bool get acceptsPlaybackPosition => !_isSeeking;

  double sliderValue({
    required Duration position,
    required Duration duration,
  }) {
    final value = _dragValue ??
        (duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0);
    return value.clamp(0.0, 1.0);
  }

  void updateDragValue(double value) {
    _isSeeking = true;
    _dragValue = value.clamp(0.0, 1.0);
  }

  Duration finishSeek(double value, Duration duration) {
    final clampedValue = value.clamp(0.0, 1.0);
    _isSeeking = false;
    _dragValue = null;
    return Duration(
      milliseconds: (clampedValue * duration.inMilliseconds).round(),
    );
  }
}

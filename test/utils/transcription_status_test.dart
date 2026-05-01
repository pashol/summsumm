import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/utils/transcription_status.dart';

void main() {
  test('uses explicit transcription status when available', () {
    expect(transcriptionStatusLabel('Loading models...'), 'Loading models...');
  });

  test('uses actionable fallback instead of generic preparing', () {
    expect(transcriptionStatusLabel(null), 'Starting transcription...');
    expect(transcriptionStatusLabel(''), 'Starting transcription...');
  });
}

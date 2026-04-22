import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/wav_writer.dart';

void main() {
  group('WavWriter', () {
    test('creates valid WAV file with correct header', () async {
      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/test_wav_writer.wav';
      
      final writer = WavWriter(path: path, sampleRate: 16000, numChannels: 1);
      await writer.open();
      
      // Write 1 second of silence (16000 samples * 2 bytes = 32000 bytes)
      final pcmData = Uint8List(32000);
      await writer.writeChunk(pcmData);
      
      await writer.close();
      
      final file = File(path);
      expect(await file.exists(), true);
      
      final bytes = await file.readAsBytes();
      expect(bytes.length, 44 + 32000); // header + data
      
      // Check RIFF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // Check WAVE format
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // Check fmt chunk
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      
      // Cleanup
      await file.delete();
    });
  });
}

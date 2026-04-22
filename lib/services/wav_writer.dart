import 'dart:io';
import 'dart:typed_data';

class WavWriter {
  final String path;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  
  RandomAccessFile? _file;
  int _totalDataBytes = 0;
  bool _isOpen = false;
  
  WavWriter({
    required this.path,
    required this.sampleRate,
    required this.numChannels,
    this.bitsPerSample = 16,
  });
  
  Future<void> open() async {
    if (_isOpen) return;
    
    final file = File(path);
    _file = await file.open(mode: FileMode.write);
    
    // Write placeholder header (44 bytes)
    await _file!.writeFrom(Uint8List(44));
    _isOpen = true;
  }
  
  Future<void> writeChunk(Uint8List pcmData) async {
    if (!_isOpen || _file == null) {
      throw StateError('WavWriter not opened. Call open() first.');
    }
    
    await _file!.writeFrom(pcmData);
    _totalDataBytes += pcmData.length;
  }
  
  Future<void> close() async {
    if (!_isOpen || _file == null) return;
    
    // Write proper header at beginning
    await _file!.setPosition(0);
    final header = _buildWavHeader();
    await _file!.writeFrom(header);
    
    await _file!.close();
    _isOpen = false;
  }
  
  Uint8List _buildWavHeader() {
    final header = Uint8List(44);
    final data = ByteData.sublistView(header);
    
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final totalFileSize = 36 + _totalDataBytes;
    
    // RIFF chunk descriptor
    header.setRange(0, 4, 'RIFF'.codeUnits);
    data.setUint32(4, totalFileSize, Endian.little);
    header.setRange(8, 12, 'WAVE'.codeUnits);
    
    // fmt sub-chunk
    header.setRange(12, 16, 'fmt '.codeUnits);
    data.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    data.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    data.setUint16(22, numChannels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    
    // data sub-chunk
    header.setRange(36, 40, 'data'.codeUnits);
    data.setUint32(40, _totalDataBytes, Endian.little);
    
    return header;
  }
}

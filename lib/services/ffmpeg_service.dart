import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

Future<String> convertAudioToWav(String inputPath) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath =
      '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.wav';

  final args = [
    '-y',
    '-i',
    inputPath,
    '-vn',
    '-ac',
    '1',
    '-ar',
    '16000',
    '-acodec',
    'pcm_s16le',
    outputPath,
  ];

  if (Platform.isLinux) {
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) {
      throw StateError('Failed to convert audio to WAV: ${result.stderr}');
    }
    return outputPath;
  }

  final cmd = args.join(' ');
  final session = await FFmpegKit.execute(cmd);
  final returnCode = await session.getReturnCode();

  if (!ReturnCode.isSuccess(returnCode)) {
    final logs = await session.getAllLogsAsString();
    throw StateError('Failed to convert audio to WAV: $logs');
  }

  return outputPath;
}

Future<bool> isFfmpegAvailable() async {
  if (Platform.isLinux) {
    final result = await Process.run('which', ['ffmpeg']);
    return result.exitCode == 0;
  }
  return true;
}

import 'package:flutter/services.dart';

class ProcessingService {
  static const _channel = MethodChannel('app.summsumm/processing');

  Future<void> start() async {
    try {
      await _channel.invokeMethod('startProcessingService');
    } on PlatformException catch (e) {
      throw Exception('Failed to start processing service: ${e.message}');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopProcessingService');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop processing service: ${e.message}');
    }
  }
}
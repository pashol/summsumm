import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android packaging stages Sherpa ONNX Runtime before plugin JNI libs',
      () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(buildGradle, contains('generated/sherpaOnnxRuntimeJniLibs'));
    expect(buildGradle, contains('sherpa_onnx_android_arm64'));
    expect(buildGradle, contains('sherpa_onnx_android_armeabi'));
    expect(buildGradle, contains('sherpa_onnx_android_x86_64'));
  });
}

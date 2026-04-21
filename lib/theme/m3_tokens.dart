import 'package:flutter/material.dart';

class M3Tokens {
  M3Tokens._();

  // Seed color
  static const Color seedColor = Color(0xFF4F46E5);

  // Duration constants
  static const Duration durationMicro = Duration(milliseconds: 200);
  static const Duration durationStandard = Duration(milliseconds: 300);
  static const Duration durationAnimatable = Duration(milliseconds: 400);
  static const Duration durationSpring = Duration(milliseconds: 500);
  static const Duration durationPage = Duration(milliseconds: 600);

  // Spring curves
  static const Curve spatialSpring = Curves.elasticOut;
  static const Curve effectsSpring = Curves.easeOutCubic;
  static const Cubic buttonPressCurve = Cubic(0.34, 1.56, 0.64, 1);

  // Shape tokens
  static final BorderRadius cornerSmall = BorderRadius.circular(8);
  static final BorderRadius cornerMedium = BorderRadius.circular(12);
  static final BorderRadius cornerLarge = BorderRadius.circular(16);
  static final BorderRadius cornerXLarge = BorderRadius.circular(28);
  static final BorderRadius pillShape = StadiumBorder();

  // Custom squircle (continuous corners)
  static final BorderRadius squircle = BorderRadius.circular(20);
}
import 'package:flutter/material.dart';

extension ReducedMotion on BuildContext {
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}

Duration animDuration(BuildContext context, Duration base) {
  return context.reduceMotion ? Duration.zero : base;
}
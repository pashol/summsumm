import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

Locale _resolveLocale(String? languageCode) {
  if (languageCode != null) {
    for (final code in kSupportedLocaleCodes) {
      if (code == languageCode) {
        return Locale(code);
      }
    }
  }
  final systemLocale = PlatformDispatcher.instance.locale;
  for (final code in kSupportedLocaleCodes) {
    if (systemLocale.languageCode == code) {
      return Locale(code);
    }
  }
  return const Locale('en');
}

final localeProvider = Provider<Locale>((ref) {
  final settings = ref.watch(settingsProvider);
  return _resolveLocale(settings.localeOverride);
});

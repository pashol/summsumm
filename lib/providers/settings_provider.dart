import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/custom_prompt.dart';
import '../models/transcription_config.dart';
import '../services/secure_storage_service.dart';

part 'settings_provider.g.dart';

const _prefsKey = 'app_settings_json';
const _validProviders = {'openrouter', 'openai'};
const kSupportedLocaleCodes = ['en', 'de'];

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(SecureStorageRef ref) =>
    SecureStorageService();

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  AppSettings build() => AppSettings.defaults();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        state = AppSettings.fromJsonString(json);
      } catch (e, stack) {
        debugPrint('Settings.load failed to parse persisted JSON: $e\n$stack');
      }
    }
  }

  Future<void> _persist(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, s.toJsonString());
  }

  Future<void> setOpenRouterModel(String model) async {
    final next = state.copyWith(openrouterModel: model);
    state = next;
    await _persist(next);
  }

  Future<void> setOpenAiModel(String model) async {
    final next = state.copyWith(openaiModel: model);
    state = next;
    await _persist(next);
  }

  Future<void> setProvider(String provider) async {
    if (!_validProviders.contains(provider)) {
      debugPrint('Settings.setProvider rejected unknown provider: $provider');
      return;
    }
    var next = state.copyWith(provider: provider);
    if (provider == 'openai' && next.openaiModel.isEmpty) {
      next = next.copyWith(openaiModel: kOpenAiModels.first.id);
    }
    state = next;
    await _persist(next);
  }

  Future<void> setLanguage(String language) async {
    if (!kSupportedLanguages.contains(language)) {
      debugPrint('Settings.setLanguage rejected unsupported language: $language');
      return;
    }
    final next = state.copyWith(language: language);
    state = next;
    await _persist(next);
  }

  Future<void> setSummaryStyle(String style) async {
    final next = state.copyWith(summaryStyle: style);
    state = next;
    await _persist(next);
  }

  void setTtsSpeed(double speed) {
    state = state.copyWith(ttsSpeed: speed);
  }

  Future<void> setDebugMode(bool enabled) async {
    final next = state.copyWith(debugMode: enabled);
    state = next;
    await _persist(next);
  }

  Future<void> persistSettings() async {
    await _persist(state);
  }

  Future<void> persistSettingsDirect(AppSettings s) async {
    state = s;
    await _persist(s);
  }

  Future<void> setLocaleOverride(String? languageCode) async {
    if (languageCode != null && !kSupportedLocaleCodes.contains(languageCode)) {
      debugPrint('Settings.setLocaleOverride rejected unsupported locale: $languageCode');
      return;
    }
    final next = state.copyWith(localeOverride: languageCode);
    state = next;
    await _persist(next);
  }

  Future<void> setTranscriptionStrategy(TranscriptionStrategy strategy) async {
    final next = state.copyWith(transcriptionStrategy: strategy);
    state = next;
    await _persist(next);
  }

  Future<void> setOnDeviceModelSize(ModelSize size) async {
    final next = state.copyWith(onDeviceModelSize: size);
    state = next;
    await _persist(next);
  }

  Future<void> setEnableRealTimeTranscription(bool enabled) async {
    final next = state.copyWith(enableRealTimeTranscription: enabled);
    state = next;
    await _persist(next);
  }

  Future<void> setOnDeviceDiarization(bool enabled) async {
    final next = state.copyWith(onDeviceDiarization: enabled);
    state = next;
    await _persist(next);
  }

  Future<void> setStreamingModelLanguage(String language) async {
    final next = state.copyWith(streamingModelLanguage: language);
    state = next;
    await _persist(next);
  }

  Future<void> setCompressAudioStorage(bool enabled) async {
    final next = state.copyWith(compressAudioStorage: enabled);
    state = next;
    await _persist(next);
  }

  Future<void> setLocalLibraryChatEnabled(bool enabled) async {
    final next = state.copyWith(localLibraryChatEnabled: enabled);
    state = next;
    await _persist(next);
  }

  Future<void> setPromptOverride(String style, String text) async {
    final nextOverrides = Map<String, String>.from(state.promptOverrides);
    nextOverrides[style] = text;
    final next = state.copyWith(promptOverrides: nextOverrides);
    state = next;
    await _persist(next);
  }

  Future<void> resetPromptOverride(String style) async {
    final nextOverrides = Map<String, String>.from(state.promptOverrides);
    nextOverrides.remove(style);
    final next = state.copyWith(promptOverrides: nextOverrides);
    state = next;
    await _persist(next);
  }

  Future<String> addCustomPrompt(String name, String text) async {
    final id = const Uuid().v4();
    final prompt = CustomPrompt(id: id, name: name, text: text);
    final nextPrompts = [...state.customPrompts, prompt];
    final next = state.copyWith(customPrompts: nextPrompts);
    state = next;
    await _persist(next);
    return id;
  }

  Future<void> updateCustomPrompt(String id, {String? name, String? text}) async {
    final nextPrompts = state.customPrompts.map((p) {
      if (p.id == id) {
        return p.copyWith(name: name ?? p.name, text: text ?? p.text);
      }
      return p;
    }).toList();
    final next = state.copyWith(customPrompts: nextPrompts);
    state = next;
    await _persist(next);
  }

  Future<void> deleteCustomPrompt(String id) async {
    final nextPrompts = state.customPrompts.where((p) => p.id != id).toList();
    final next = state.copyWith(
      customPrompts: nextPrompts,
      selectedCustomPromptId:
          state.selectedCustomPromptId == id ? null : state.selectedCustomPromptId,
    );
    state = next;
    await _persist(next);
  }

  Future<void> setSelectedCustomPrompt(String? id) async {
    final next = state.copyWith(selectedCustomPromptId: id);
    state = next;
    await _persist(next);
  }

  Future<String?> getApiKey(String provider) =>
      ref.read(secureStorageProvider).getApiKey(provider);

  Future<void> saveApiKey(String provider, String key) =>
      ref.read(secureStorageProvider).saveApiKey(provider, key);
}

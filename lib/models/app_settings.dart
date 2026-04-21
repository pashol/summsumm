import 'dart:convert';
import 'transcription_config.dart';

class AppSettings {
  final String provider;
  final String openrouterModel;
  final String openaiModel;
  final String language;
  final String summaryStyle;
  final double ttsSpeed;
  final String openaiKey;
  final String openrouterKey;
  final bool debugMode;
  final String? localeOverride;
  final TranscriptionStrategy transcriptionStrategy;
  final ModelSize onDeviceModelSize;
  final bool enableRealTimeTranscription;
  final bool onDeviceDiarization;

  const AppSettings({
    required this.provider,
    required this.openrouterModel,
    required this.openaiModel,
    required this.language,
    required this.summaryStyle,
    required this.ttsSpeed,
    required this.openaiKey,
    required this.openrouterKey,
    this.debugMode = false,
    this.localeOverride,
    this.transcriptionStrategy = TranscriptionStrategy.cloud,
    this.onDeviceModelSize = ModelSize.base,
    this.enableRealTimeTranscription = false,
    this.onDeviceDiarization = true,
  });

  factory AppSettings.defaults() => const AppSettings(
        provider: 'openrouter',
        openrouterModel: '',
        openaiModel: '',
        language: 'Same as input',
        summaryStyle: 'structured',
        ttsSpeed: 1.0,
        openaiKey: '',
        openrouterKey: '',
        debugMode: false,
        localeOverride: null,
        transcriptionStrategy: TranscriptionStrategy.cloud,
        onDeviceModelSize: ModelSize.base,
        enableRealTimeTranscription: false,
        onDeviceDiarization: true,
      );

  AppSettings copyWith({
    String? provider,
    String? openrouterModel,
    String? openaiModel,
    String? language,
    String? summaryStyle,
    double? ttsSpeed,
    String? openaiKey,
    String? openrouterKey,
    bool? debugMode,
    String? localeOverride,
    TranscriptionStrategy? transcriptionStrategy,
    ModelSize? onDeviceModelSize,
    bool? enableRealTimeTranscription,
    bool? onDeviceDiarization,
  }) =>
      AppSettings(
        provider: provider ?? this.provider,
        openrouterModel: openrouterModel ?? this.openrouterModel,
        openaiModel: openaiModel ?? this.openaiModel,
        language: language ?? this.language,
        summaryStyle: summaryStyle ?? this.summaryStyle,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        openaiKey: openaiKey ?? this.openaiKey,
        openrouterKey: openrouterKey ?? this.openrouterKey,
        debugMode: debugMode ?? this.debugMode,
        localeOverride: localeOverride ?? this.localeOverride,
        transcriptionStrategy: transcriptionStrategy ?? this.transcriptionStrategy,
        onDeviceModelSize: onDeviceModelSize ?? this.onDeviceModelSize,
        enableRealTimeTranscription: enableRealTimeTranscription ?? this.enableRealTimeTranscription,
        onDeviceDiarization: onDeviceDiarization ?? this.onDeviceDiarization,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'openrouterModel': openrouterModel,
        'openaiModel': openaiModel,
        'language': language,
        'summaryStyle': summaryStyle,
        'ttsSpeed': ttsSpeed,
        'openaiKey': openaiKey,
        'openrouterKey': openrouterKey,
        'debugMode': debugMode,
        'localeOverride': localeOverride,
        'transcriptionStrategy': transcriptionStrategy.name,
        'onDeviceModelSize': onDeviceModelSize.name,
        'enableRealTimeTranscription': enableRealTimeTranscription,
        'onDeviceDiarization': onDeviceDiarization,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        provider: json['provider'] as String? ?? 'openrouter',
        openrouterModel: json['openrouterModel'] as String? ?? '',
        openaiModel: json['openaiModel'] as String? ?? '',
        language: json['language'] as String? ?? 'English',
        summaryStyle: json['summaryStyle'] as String? ?? 'structured',
        ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
        openaiKey: json['openaiKey'] as String? ?? '',
        openrouterKey: json['openrouterKey'] as String? ?? '',
        debugMode: json['debugMode'] as bool? ?? false,
        localeOverride: json['localeOverride'] as String?,
        transcriptionStrategy: TranscriptionStrategy.values.byName(
          json['transcriptionStrategy'] as String? ?? 'cloud',
        ),
        onDeviceModelSize: ModelSize.values.byName(
          json['onDeviceModelSize'] as String? ?? 'base',
        ),
        enableRealTimeTranscription:
            json['enableRealTimeTranscription'] as bool? ?? false,
        onDeviceDiarization: json['onDeviceDiarization'] as bool? ?? true,
      );

  String get activeModel =>
      provider == 'openai' ? openaiModel : openrouterModel;

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.provider == provider &&
        other.openrouterModel == openrouterModel &&
        other.openaiModel == openaiModel &&
        other.language == language &&
        other.summaryStyle == summaryStyle &&
        other.ttsSpeed == ttsSpeed &&
        other.openaiKey == openaiKey &&
        other.openrouterKey == openrouterKey &&
        other.debugMode == debugMode &&
        other.localeOverride == localeOverride &&
        other.transcriptionStrategy == transcriptionStrategy &&
        other.onDeviceModelSize == onDeviceModelSize &&
        other.enableRealTimeTranscription == enableRealTimeTranscription &&
        other.onDeviceDiarization == onDeviceDiarization;
  }

  @override
  int get hashCode => Object.hash(
        provider,
        openrouterModel,
        openaiModel,
        language,
        summaryStyle,
        ttsSpeed,
        openaiKey,
        openrouterKey,
        debugMode,
        localeOverride,
        transcriptionStrategy,
        onDeviceModelSize,
        enableRealTimeTranscription,
        onDeviceDiarization,
      );
}

class CuratedModel {
  final String id;
  final String name;
  final String series;

  const CuratedModel({
    required this.id,
    required this.name,
    required this.series,
  });
}

const kCuratedModels = [
  CuratedModel(
    id: 'openrouter/free',
    name: 'Auto (Best Free Model)',
    series: 'Auto',
  ),
  CuratedModel(
    id: 'google/gemini-3-flash-preview',
    name: 'Gemini 3 Flash',
    series: 'Google',
  ),
  CuratedModel(
    id: 'deepseek/deepseek-v3.2',
    name: 'DeepSeek V3.2',
    series: 'DeepSeek',
  ),
  CuratedModel(
    id: 'anthropic/claude-haiku-4.5',
    name: 'Claude Haiku 4.5',
    series: 'Anthropic',
  ),
  CuratedModel(
    id: 'openai/gpt-5.4-mini',
    name: 'GPT-5.4 Mini',
    series: 'OpenAI',
  ),
  CuratedModel(
    id: 'mistralai/mistral-small-3.2-24b-instruct',
    name: 'Mistral Small 3.2',
    series: 'Mistral',
  ),
  CuratedModel(
    id: 'anthropic/claude-sonnet-4.6',
    name: 'Claude Sonnet 4.6',
    series: 'Anthropic',
  ),
  CuratedModel(
    id: 'anthropic/claude-opus-4.6',
    name: 'Claude Opus 4.6',
    series: 'Anthropic',
  ),
];

const kOpenAiModels = [
  CuratedModel(id: 'gpt-5.4-nano', name: 'GPT-5.4 Nano', series: 'OpenAI'),
  CuratedModel(id: 'gpt-5.4-mini', name: 'GPT-5.4 Mini', series: 'OpenAI'),
  CuratedModel(id: 'gpt-5.4', name: 'GPT-5.4', series: 'OpenAI'),
];

const kSupportedLanguages = [
  'Same as input',
  'English',
  'German',
  'French',
  'Spanish',
  'Italian',
  'Portuguese',
  'Russian',
  'Chinese',
  'Japanese',
  'Korean',
  'Arabic',
  'Hindi',
  'Dutch',
  'Polish',
  'Turkish',
];

const Map<String, String> kLanguageTtsCode = {
  'English': 'en-US',
  'German': 'de-DE',
  'French': 'fr-FR',
  'Spanish': 'es-ES',
  'Italian': 'it-IT',
  'Portuguese': 'pt-BR',
  'Russian': 'ru-RU',
  'Chinese': 'zh-CN',
  'Japanese': 'ja-JP',
  'Korean': 'ko-KR',
  'Arabic': 'ar-SA',
  'Hindi': 'hi-IN',
  'Dutch': 'nl-NL',
  'Polish': 'pl-PL',
  'Turkish': 'tr-TR',
};

import 'dart:convert';

class AppSettings {
  final String provider;
  final String openrouterModel;
  final String openaiModel;
  final String language;
  final double ttsSpeed;
  final String openaiKey;
  final String openrouterKey;

  const AppSettings({
    required this.provider,
    required this.openrouterModel,
    required this.openaiModel,
    required this.language,
    required this.ttsSpeed,
    required this.openaiKey,
    required this.openrouterKey,
  });

  factory AppSettings.defaults() => const AppSettings(
        provider: 'openrouter',
        openrouterModel: '',
        openaiModel: '',
        language: 'English',
        ttsSpeed: 1.0,
        openaiKey: '',
        openrouterKey: ''
      );

  AppSettings copyWith({
    String? provider,
    String? openrouterModel,
    String? openaiModel,
    String? language,
    double? ttsSpeed,
    String? openaiKey,
    String? openrouterKey,
  }) =>
      AppSettings(
        provider: provider ?? this.provider,
    openrouterModel: openrouterModel ?? this.openrouterModel,
    openaiModel: openaiModel ?? this.openaiModel,
    language: language ?? this.language,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    openaiKey: openaiKey ?? this.openaiKey,
    openrouterKey: openrouterKey ?? this.openrouterKey,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'openrouterModel': openrouterModel,
        'openaiModel': openaiModel,
        'language': language,
        'ttsSpeed': ttsSpeed,
        'openaiKey': openaiKey,
        'openrouterKey': openrouterKey,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        provider: json['provider'] as String? ?? 'openrouter',
        openrouterModel: json['openrouterModel'] as String? ?? '',
        openaiModel: json['openaiModel'] as String? ?? '',
        language: json['language'] as String? ?? 'English',
        ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
        openaiKey: json['openaiKey'] as String? ?? '',
        openrouterKey: json['openrouterKey'] as String? ?? ''
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
        other.ttsSpeed == ttsSpeed &&
        other.openaiKey == openaiKey &&
        other.openrouterKey == openrouterKey;
  }

  @override
  int get hashCode => Object.hash(
        provider,
        openrouterModel,
        openaiModel,
        language,
        ttsSpeed,
        openaiKey,
        openrouterKey,
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
      id: 'openrouter/free', name: 'Auto (Best Free Model)', series: 'Auto'),
  CuratedModel(
      id: 'google/gemini-3-flash-preview',
      name: 'Gemini 3 Flash',
      series: 'Google'),
  CuratedModel(
      id: 'deepseek/deepseek-v3.2', name: 'DeepSeek V3.2', series: 'DeepSeek'),
  CuratedModel(
      id: 'anthropic/claude-haiku-4.5',
      name: 'Claude Haiku 4.5',
      series: 'Anthropic'),
  CuratedModel(
      id: 'openai/gpt-5.4-mini', name: 'GPT-5.4 Mini', series: 'OpenAI'),
  CuratedModel(
      id: 'mistralai/mistral-small-3.2-24b-instruct',
      name: 'Mistral Small 3.2',
      series: 'Mistral'),
  CuratedModel(
      id: 'anthropic/claude-sonnet-4.6',
      name: 'Claude Sonnet 4.6',
      series: 'Anthropic'),
  CuratedModel(
      id: 'anthropic/claude-opus-4.6',
      name: 'Claude Opus 4.6',
      series: 'Anthropic'),
];

const kOpenAiModels = [
  CuratedModel(id: 'gpt-5.4-nano', name: 'GPT-5.4 Nano', series: 'OpenAI'),
  CuratedModel(id: 'gpt-5.4-mini', name: 'GPT-5.4 Mini', series: 'OpenAI'),
  CuratedModel(id: 'gpt-5.4', name: 'GPT-5.4', series: 'OpenAI'),
];

const kSupportedLanguages = [
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

class AIModel {
  final String id;
  final String name;
  final bool isFree;
  final int contextLength;
  final String? pricingPrompt;
  final String? pricingCompletion;
  final String modality;

  const AIModel({
    required this.id,
    required this.name,
    required this.isFree,
    this.contextLength = 0,
    this.pricingPrompt,
    this.pricingCompletion,
    this.modality = 'text',
  });

  String get displayName => isFree ? '$name [Free]' : name;

  String get series {
    final slash = id.indexOf('/');
    if (slash > 0) return id.substring(0, slash);
    return 'Other';
  }

  String get contextLabel {
    if (contextLength <= 0) return '';
    if (contextLength >= 1000000) {
      return '${(contextLength / 1000000).toStringAsFixed(1)}M';
    }
    if (contextLength >= 1000) return '${(contextLength / 1000).toInt()}K';
    return '$contextLength';
  }

  bool get isTextOnly =>
      modality.contains('text') && !modality.contains('image');

  factory AIModel.fromOpenRouterJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? id;
    final isFree = id.endsWith(':free');
    final contextLength = (json['context_length'] as num?)?.toInt() ?? 0;
    final pricing = json['pricing'] as Map<String, dynamic>?;
    final arch = json['architecture'] as Map<String, dynamic>?;
    final modality = arch?['modality'] as String? ?? 'text';
    return AIModel(
      id: id,
      name: name,
      isFree: isFree,
      contextLength: contextLength,
      pricingPrompt: pricing?['prompt'] as String?,
      pricingCompletion: pricing?['completion'] as String?,
      modality: modality,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIModel &&
        other.id == id &&
        other.name == name &&
        other.isFree == isFree &&
        other.contextLength == contextLength &&
        other.pricingPrompt == pricingPrompt &&
        other.pricingCompletion == pricingCompletion &&
        other.modality == modality;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        isFree,
        contextLength,
        pricingPrompt,
        pricingCompletion,
        modality,
      );
}

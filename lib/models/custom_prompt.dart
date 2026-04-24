class CustomPrompt {
  final String id;
  final String name;
  final String text;

  const CustomPrompt({
    required this.id,
    required this.name,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
      };

  factory CustomPrompt.fromJson(Map<String, dynamic> json) => CustomPrompt(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  CustomPrompt copyWith({
    String? id,
    String? name,
    String? text,
  }) =>
      CustomPrompt(
        id: id ?? this.id,
        name: name ?? this.name,
        text: text ?? this.text,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomPrompt &&
        other.id == id &&
        other.name == name &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(id, name, text);
}

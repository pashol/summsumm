class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, String> toApiMap() => {'role': role, 'content': content};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.role == role &&
        other.content == content;
  }

  @override
  int get hashCode => Object.hash(role, content);
}

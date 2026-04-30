class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.role,
    required this.content,
    this.metadata,
  });

  Map<String, dynamic> toApiMap() => {
    'role': role,
    'content': content,
    if (metadata != null) 'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.role == role &&
        other.content == content &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(role, content, _deepHash(metadata));
}

int _deepHash(Map<String, dynamic>? map) {
  if (map == null) return 0;
  var hash = map.length;
  for (final entry in map.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    hash = hash ^ Object.hash(
      entry.key,
      _hashValue(entry.value),
    );
  }
  return hash;
}

int _hashValue(dynamic value) {
  if (value is Map) {
    return _deepHash(value.cast<String, dynamic>());
  } else if (value is List) {
    var hash = value.length;
    for (var i = 0; i < value.length; i++) {
      hash = hash ^ Object.hash(i, _hashValue(value[i]));
    }
    return hash;
  } else {
    return value.hashCode;
  }
}

bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final aVal = a[key];
    final bVal = b[key];
    if (aVal is Map && bVal is Map) {
      if (!_mapEquals(
        aVal.cast<String, dynamic>(),
        bVal.cast<String, dynamic>(),
      )) {
        return false;
      }
    } else if (aVal is List && bVal is List) {
      if (aVal.length != bVal.length) return false;
      for (var i = 0; i < aVal.length; i++) {
        final aItem = aVal[i];
        final bItem = bVal[i];
        if (aItem is Map && bItem is Map) {
          if (!_mapEquals(
            aItem.cast<String, dynamic>(),
            bItem.cast<String, dynamic>(),
          )) {
            return false;
          }
        } else if (aItem != bItem) {
          return false;
        }
      }
    } else if (aVal != bVal) {
      return false;
    }
  }
  return true;
}

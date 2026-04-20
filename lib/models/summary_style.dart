enum MeetingType { meeting, document }

enum SummaryStyle {
  concise,
  brief,
  detailed,
  structured;

  String get displayName {
    switch (this) {
      case SummaryStyle.concise:
        return 'Concise';
      case SummaryStyle.brief:
        return 'Brief';
      case SummaryStyle.detailed:
        return 'Detailed';
      case SummaryStyle.structured:
        return 'Structured';
    }
  }

  static List<SummaryStyle> forType(MeetingType type) {
    switch (type) {
      case MeetingType.meeting:
        return [concise, detailed, structured];
      case MeetingType.document:
        return [concise, brief, detailed];
    }
  }
}

String langSuffix(String language, String subject) {
  if (language == 'Same as input') return '';
  return '\n\nIMPORTANT: The summary must be in $language.';
}

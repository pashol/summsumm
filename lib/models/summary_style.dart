import 'package:flutter/widgets.dart';
import 'package:summsumm/l10n/app_localizations.dart';

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

extension SummaryStyleLocalization on SummaryStyle {
  String localizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SummaryStyle.concise:
        return l10n.styleConcise;
      case SummaryStyle.brief:
        return l10n.styleBrief;
      case SummaryStyle.detailed:
        return l10n.styleDetailed;
      case SummaryStyle.structured:
        return l10n.styleStructured;
    }
  }
}

String langSuffix(String language, String subject) {
  if (language == 'Same as input') return '';
  return '\n\nIMPORTANT: The summary must be in $language.';
}

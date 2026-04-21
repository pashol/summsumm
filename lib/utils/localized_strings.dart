import 'package:flutter/widgets.dart';
import 'package:summsumm/l10n/app_localizations.dart';

String localizedLanguageName(BuildContext context, String languageKey) {
  final l10n = AppLocalizations.of(context)!;
  switch (languageKey) {
    case 'Same as input':
      return l10n.langSameAsInput;
    case 'English':
      return l10n.langEnglish;
    case 'German':
      return l10n.langGerman;
    case 'French':
      return l10n.langFrench;
    case 'Spanish':
      return l10n.langSpanish;
    case 'Italian':
      return l10n.langItalian;
    case 'Portuguese':
      return l10n.langPortuguese;
    case 'Russian':
      return l10n.langRussian;
    case 'Chinese':
      return l10n.langChinese;
    case 'Japanese':
      return l10n.langJapanese;
    case 'Korean':
      return l10n.langKorean;
    case 'Arabic':
      return l10n.langArabic;
    case 'Hindi':
      return l10n.langHindi;
    case 'Dutch':
      return l10n.langDutch;
    case 'Polish':
      return l10n.langPolish;
    case 'Turkish':
      return l10n.langTurkish;
    default:
      return languageKey;
  }
}

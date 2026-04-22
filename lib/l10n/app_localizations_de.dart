// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'KI-Textzusammenfassung';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSetupHint =>
      'Lege deinen API-Schlüssel fest, um zu beginnen.';

  @override
  String get settingsModelSection => 'Modell';

  @override
  String get settingsProviderLabel => 'Anbieter';

  @override
  String get settingsOpenRouter => 'OpenRouter';

  @override
  String get settingsOpenAi => 'OpenAI';

  @override
  String get settingsMoreModels => 'Weitere Modelle';

  @override
  String get settingsSearchAllModels => 'Alle OpenRouter-Modelle durchsuchen';

  @override
  String get settingsEnterKeyFirst =>
      'Gib zuerst deinen API-Schlüssel ein, um Modelle zu laden.';

  @override
  String settingsApiKeySection(String provider) {
    return '$provider API-Schlüssel';
  }

  @override
  String get settingsApiKeyLabel => 'API-Schlüssel';

  @override
  String get settingsSaveKey => 'Schlüssel speichern';

  @override
  String get settingsTestButton => 'Testen';

  @override
  String get settingsConnectionSuccess => 'Verbindung erfolgreich!';

  @override
  String get settingsEnterApiKeyFirst => 'Zuerst einen API-Schlüssel eingeben';

  @override
  String get settingsSelectModelFirst => 'Zuerst ein Modell auswählen';

  @override
  String get settingsSummarySection => 'Zusammenfassung';

  @override
  String get settingsStyleLabel => 'Stil';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get settingsTtsSection => 'Text-to-Speech';

  @override
  String get settingsSearchModelsHint => 'Modelle suchen...';

  @override
  String settingsFailedToLoadModels(String error) {
    return 'Modelle konnten nicht geladen werden: $error';
  }

  @override
  String get settingsAppLanguageLabel => 'App-Sprache';

  @override
  String get settingsSystemDefault => 'Systemstandard';

  @override
  String get libraryTitle => 'Bibliothek';

  @override
  String get libraryImportFile => 'Datei importieren';

  @override
  String get libraryArchived => 'Archiviert';

  @override
  String get librarySettings => 'Einstellungen';

  @override
  String get libraryNoItems => 'Noch keine Einträge';

  @override
  String libraryError(String error) {
    return 'Fehler: $error';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get libraryShare => 'Teilen';

  @override
  String get libraryRename => 'Umbenennen';

  @override
  String get libraryArchive => 'Archivieren';

  @override
  String get libraryDelete => 'Löschen';

  @override
  String get libraryDeleteDocument => 'Dokument löschen?';

  @override
  String get libraryDeleteMeeting => 'Meeting löschen?';

  @override
  String get libraryDeleteDocumentConfirm =>
      'Dies wird diese Dokumentzusammenfassung dauerhaft löschen.';

  @override
  String get libraryDeleteMeetingConfirm =>
      'Dies wird die Aufnahme und alle Daten dauerhaft löschen.';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get saveButton => 'Speichern';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get libraryRenameMeeting => 'Meeting umbenennen';

  @override
  String get summarizeButton => 'Zusammenfassen';

  @override
  String get transcribeButton => 'Transkribieren';

  @override
  String get retryButton => 'Wiederholen';

  @override
  String get libraryFailedDetails => 'Fehlgeschlagen — tippen für Details';

  @override
  String get libraryArchivedSnackbar => 'Meeting archiviert';

  @override
  String get undoButton => 'Rückgängig';

  @override
  String get shareTitle => 'Teilen';

  @override
  String get shareAudio => 'Audio teilen';

  @override
  String get shareTranscript => 'Transkript teilen';

  @override
  String get shareSummary => 'Zusammenfassung teilen';

  @override
  String get shareAudioNotFound => 'Audiodatei nicht gefunden';

  @override
  String get meetingDetailTabSummary => 'Zusammenfassung';

  @override
  String get meetingDetailTabTranscript => 'Transkript';

  @override
  String get meetingDetailTabChat => 'Chat';

  @override
  String get meetingDetailDuration => 'Dauer';

  @override
  String get meetingDetailRecorded => 'Aufgenommen';

  @override
  String get meetingDetailTranscribedBy => 'Transkribiert von';

  @override
  String get meetingDetailNoTranscript =>
      'Noch kein Transkript.\nWechsle zum Transkript-Tab, um zu transkribieren.';

  @override
  String get meetingDetailTranscribing => 'Transkribieren…';

  @override
  String get meetingDetailSummarizing => 'Zusammenfassen…';

  @override
  String get meetingDetailErrorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get meetingDetailGenerateSummary => 'Zusammenfassung erstellen';

  @override
  String meetingDetailGenerateConfirm(String language, String style) {
    return 'Eine neue Zusammenfassung in $language mit $style-Stil erstellen?';
  }

  @override
  String get meetingDetailGenerate => 'Erstellen';

  @override
  String get meetingDetailNotRecording =>
      'Dies ist ein Dokument, keine Aufnahme.\nWechsle zum Zusammenfassung-Tab, um es zu verarbeiten.';

  @override
  String get meetingDetailDiarizationRequires =>
      'Diarisierung erfordert OpenRouter';

  @override
  String get meetingDetailDiarizeSpeakers => 'Sprecher diarisieren';

  @override
  String get meetingDetailDocumentContent =>
      'Dies ist der importierte Dokumentinhalt, kein Transkript.';

  @override
  String get meetingDetailDocumentNotReady =>
      'Dokumentinhalt noch nicht verfügbar.\nWechsle zum Zusammenfassung-Tab, um es zu verarbeiten.';

  @override
  String get meetingDetailTranscribeFirst =>
      'Transkribiere zuerst das Meeting, um zu chatten.';

  @override
  String get meetingDetailChatHint => 'Frage zu diesem Meeting…';

  @override
  String summarySheetFailedRecording(String error) {
    return 'Aufnahme fehlgeschlagen: $error';
  }

  @override
  String summarySheetFailedVoice(String error) {
    return 'Spracheingabe fehlgeschlagen: $error';
  }

  @override
  String get summarySheetNoApiKey =>
      'Kein API-Schlüssel konfiguriert. Öffne zuerst die Einstellungen.';

  @override
  String get summarySheetCopied => 'In die Zwischenablage kopiert';

  @override
  String get summarySheetFactCheck => 'Faktencheck';

  @override
  String get summarySheetAiSummary => 'KI-Zusammenfassung';

  @override
  String get closeButton => 'Schließen';

  @override
  String get summarySheetCopy => 'Kopieren';

  @override
  String get summarySheetReadAloud => 'Vorlesen';

  @override
  String get summarySheetPause => 'Pause';

  @override
  String get summarySheetResume => 'Fortsetzen';

  @override
  String get summarySheetStop => 'Stopp';

  @override
  String get summarySheetLastFollowUp => 'Letzte Folgefrage...';

  @override
  String get summarySheetFollowUpHint => 'Folgefrage stellen...';

  @override
  String get recordingTitle => 'Meeting aufnehmen';

  @override
  String get stopButton => 'Stopp';

  @override
  String get startButton => 'Start';

  @override
  String get recordingMicPermission =>
      'Mikrofonberechtigung ist zum Aufnehmen erforderlich';

  @override
  String recordingFailedStart(String error) {
    return 'Aufnahme fehlgeschlagen: $error';
  }

  @override
  String get liveTranscriptionTitle => 'Live-Transkription';

  @override
  String get liveTranscriptionPrompt =>
      'Sprache in Echtzeit während der Aufnahme transkribieren?\n\nDies verbraucht mehr Akku, aber du siehst den Text während du sprichst.';

  @override
  String get liveTranscriptionYes => 'Ja';

  @override
  String get liveTranscriptionNo => 'Nein';

  @override
  String liveTranscriptionFailed(String error) {
    return 'Live-Transkription fehlgeschlagen: $error';
  }

  @override
  String get liveIndicator => 'LIVE';

  @override
  String get archiveTitle => 'Archivierte Meetings';

  @override
  String archiveError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get archiveNoMeetings => 'Keine archivierten Meetings';

  @override
  String get archiveRestore => 'Wiederherstellen';

  @override
  String get archiveRestored => 'Meeting in Bibliothek wiederhergestellt';

  @override
  String carouselDocFallback(int index) {
    return 'Dok $index';
  }

  @override
  String get documentFallback => 'Dokument';

  @override
  String get styleConcise => 'Prägnant';

  @override
  String get styleBrief => 'Kurz';

  @override
  String get styleDetailed => 'Detailliert';

  @override
  String get styleStructured => 'Strukturiert';

  @override
  String get langSameAsInput => 'Wie Eingabe';

  @override
  String get langEnglish => 'Englisch';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langFrench => 'Französisch';

  @override
  String get langSpanish => 'Spanisch';

  @override
  String get langItalian => 'Italienisch';

  @override
  String get langPortuguese => 'Portugiesisch';

  @override
  String get langRussian => 'Russisch';

  @override
  String get langChinese => 'Chinesisch';

  @override
  String get langJapanese => 'Japanisch';

  @override
  String get langKorean => 'Koreanisch';

  @override
  String get langArabic => 'Arabisch';

  @override
  String get langHindi => 'Hindi';

  @override
  String get langDutch => 'Niederländisch';

  @override
  String get langPolish => 'Polnisch';

  @override
  String get langTurkish => 'Türkisch';
}

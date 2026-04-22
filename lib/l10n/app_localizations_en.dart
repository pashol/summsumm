// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Text Summarizer';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSetupHint => 'Set your API key to get started.';

  @override
  String get settingsModelSection => 'Model';

  @override
  String get settingsProviderLabel => 'Provider';

  @override
  String get settingsOpenRouter => 'OpenRouter';

  @override
  String get settingsOpenAi => 'OpenAI';

  @override
  String get settingsMoreModels => 'More models';

  @override
  String get settingsSearchAllModels => 'Search all OpenRouter models';

  @override
  String get settingsEnterKeyFirst =>
      'Enter your API key first to load models.';

  @override
  String settingsApiKeySection(String provider) {
    return '$provider API Key';
  }

  @override
  String get settingsApiKeyLabel => 'API Key';

  @override
  String get settingsSaveKey => 'Save Key';

  @override
  String get settingsTestButton => 'Test';

  @override
  String get settingsConnectionSuccess => 'Connection successful!';

  @override
  String get settingsEnterApiKeyFirst => 'Enter an API key first';

  @override
  String get settingsSelectModelFirst => 'Select a model first';

  @override
  String get settingsSummarySection => 'Summary';

  @override
  String get settingsStyleLabel => 'Style';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsTtsSection => 'Text-to-Speech';

  @override
  String get settingsSearchModelsHint => 'Search models...';

  @override
  String settingsFailedToLoadModels(String error) {
    return 'Failed to load models: $error';
  }

  @override
  String get settingsAppLanguageLabel => 'App Language';

  @override
  String get settingsSystemDefault => 'System Default';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryImportFile => 'Import file';

  @override
  String get libraryArchived => 'Archived';

  @override
  String get librarySettings => 'Settings';

  @override
  String get libraryNoItems => 'No items yet';

  @override
  String libraryError(String error) {
    return 'Error: $error';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get libraryShare => 'Share';

  @override
  String get libraryRename => 'Rename';

  @override
  String get libraryArchive => 'Archive';

  @override
  String get libraryDelete => 'Delete';

  @override
  String get libraryDeleteDocument => 'Delete Document?';

  @override
  String get libraryDeleteMeeting => 'Delete Meeting?';

  @override
  String get libraryDeleteDocumentConfirm =>
      'This will permanently delete this document summary.';

  @override
  String get libraryDeleteMeetingConfirm =>
      'This will permanently delete the recording and all data.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get saveButton => 'Save';

  @override
  String get deleteButton => 'Delete';

  @override
  String get libraryRenameMeeting => 'Rename Meeting';

  @override
  String get summarizeButton => 'Summarize';

  @override
  String get transcribeButton => 'Transcribe';

  @override
  String get retryButton => 'Retry';

  @override
  String get libraryFailedDetails => 'Failed — tap for details';

  @override
  String get libraryArchivedSnackbar => 'Meeting archived';

  @override
  String get undoButton => 'Undo';

  @override
  String get shareTitle => 'Share';

  @override
  String get shareAudio => 'Share Audio';

  @override
  String get shareTranscript => 'Share Transcript';

  @override
  String get shareSummary => 'Share Summary';

  @override
  String get shareAudioNotFound => 'Audio file not found';

  @override
  String get meetingDetailTabSummary => 'Summary';

  @override
  String get meetingDetailTabTranscript => 'Transcript';

  @override
  String get meetingDetailTabChat => 'Chat';

  @override
  String get meetingDetailDuration => 'Duration';

  @override
  String get meetingDetailRecorded => 'Recorded';

  @override
  String get meetingDetailTranscribedBy => 'Transcribed by';

  @override
  String get meetingDetailNoTranscript =>
      'No transcript yet.\nGo to the Transcript tab to transcribe.';

  @override
  String get meetingDetailTranscribing => 'Transcribing…';

  @override
  String get meetingDetailSummarizing => 'Summarizing…';

  @override
  String get meetingDetailErrorOccurred => 'An error occurred';

  @override
  String get meetingDetailGenerateSummary => 'Generate Summary';

  @override
  String meetingDetailGenerateConfirm(String language, String style) {
    return 'Generate a new summary in $language with $style style?';
  }

  @override
  String get meetingDetailGenerate => 'Generate';

  @override
  String get meetingDetailNotRecording =>
      'This is a document, not a recording.\nGo to the Summary tab to process it.';

  @override
  String get meetingDetailDiarizationRequires =>
      'Diarization requires OpenRouter';

  @override
  String get meetingDetailDiarizeSpeakers => 'Diarize speakers';

  @override
  String get meetingDetailDocumentContent =>
      'This is the imported document content, not a transcript.';

  @override
  String get meetingDetailDocumentNotReady =>
      'Document content not available yet.\nGo to the Summary tab to process it.';

  @override
  String get meetingDetailTranscribeFirst =>
      'Transcribe the meeting first to start chatting.';

  @override
  String get meetingDetailChatHint => 'Ask about this meeting…';

  @override
  String summarySheetFailedRecording(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String summarySheetFailedVoice(String error) {
    return 'Failed to process voice input: $error';
  }

  @override
  String get summarySheetNoApiKey =>
      'No API key configured. Open Settings first.';

  @override
  String get summarySheetCopied => 'Copied to clipboard';

  @override
  String get summarySheetFactCheck => 'Fact Check';

  @override
  String get summarySheetAiSummary => 'AI Summary';

  @override
  String get closeButton => 'Close';

  @override
  String get summarySheetCopy => 'Copy';

  @override
  String get summarySheetReadAloud => 'Read Aloud';

  @override
  String get summarySheetPause => 'Pause';

  @override
  String get summarySheetResume => 'Resume';

  @override
  String get summarySheetStop => 'Stop';

  @override
  String get summarySheetLastFollowUp => 'Last follow-up question...';

  @override
  String get summarySheetFollowUpHint => 'Ask a follow-up question...';

  @override
  String get recordingTitle => 'Record Meeting';

  @override
  String get stopButton => 'Stop';

  @override
  String get startButton => 'Start';

  @override
  String get recordingMicPermission =>
      'Microphone permission is required to record';

  @override
  String recordingFailedStart(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String get liveTranscriptionTitle => 'Live Transcription';

  @override
  String get liveTranscriptionPrompt =>
      'Transcribe speech in real-time while recording?\n\nThis uses more battery but lets you see text appear as you speak.';

  @override
  String get liveTranscriptionYes => 'Yes';

  @override
  String get liveTranscriptionNo => 'No';

  @override
  String liveTranscriptionFailed(String error) {
    return 'Failed to start live transcription: $error';
  }

  @override
  String get liveIndicator => 'LIVE';

  @override
  String get archiveTitle => 'Archived Meetings';

  @override
  String archiveError(String error) {
    return 'Error: $error';
  }

  @override
  String get archiveNoMeetings => 'No archived meetings';

  @override
  String get archiveRestore => 'Restore';

  @override
  String get archiveRestored => 'Meeting restored to library';

  @override
  String carouselDocFallback(int index) {
    return 'Doc $index';
  }

  @override
  String get documentFallback => 'Document';

  @override
  String get styleConcise => 'Concise';

  @override
  String get styleBrief => 'Brief';

  @override
  String get styleDetailed => 'Detailed';

  @override
  String get styleStructured => 'Structured';

  @override
  String get langSameAsInput => 'Same as input';

  @override
  String get langEnglish => 'English';

  @override
  String get langGerman => 'German';

  @override
  String get langFrench => 'French';

  @override
  String get langSpanish => 'Spanish';

  @override
  String get langItalian => 'Italian';

  @override
  String get langPortuguese => 'Portuguese';

  @override
  String get langRussian => 'Russian';

  @override
  String get langChinese => 'Chinese';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get langKorean => 'Korean';

  @override
  String get langArabic => 'Arabic';

  @override
  String get langHindi => 'Hindi';

  @override
  String get langDutch => 'Dutch';

  @override
  String get langPolish => 'Polish';

  @override
  String get langTurkish => 'Turkish';
}

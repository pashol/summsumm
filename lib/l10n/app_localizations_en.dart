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
  String get reTranscribeButton => 'Re-transcribe';

  @override
  String get reTranscribeConfirmTitle => 'Replace transcript?';

  @override
  String get reTranscribeConfirmBody =>
      'This will replace the existing transcript, diarization, and all summaries. This action cannot be undone.';

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
  String get meetingDetailTabContent => 'Content';

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

  @override
  String get onboardingWelcomeTitle => 'Summarize Anything, Anywhere';

  @override
  String get onboardingWelcomeSubtitle =>
      'AI-powered summaries from text, voice, and documents';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingSkipSetup => 'Skip Setup';

  @override
  String get onboardingFeaturesTitle => 'What You Can Do';

  @override
  String get onboardingOnlineFeatures => 'Online Features';

  @override
  String get onboardingOnlineFeaturesDesc =>
      'Text summarization, PDF summaries, cloud transcription — Requires API key';

  @override
  String get onboardingOfflineFeatures => 'Offline Features';

  @override
  String get onboardingOfflineFeaturesDesc =>
      'Meeting recording, on-device transcription — Works without internet after model download';

  @override
  String get onboardingTranscriptionNote =>
      'On-device transcription supports multiple languages. Live transcription works best with English.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingApiKeyTitle => 'Connect Your AI';

  @override
  String get onboardingApiKeySubtitle =>
      'Add an API key to use AI-powered features. You can skip this and add it later in Settings.';

  @override
  String get onboardingSkipForNow => 'Skip for Now';

  @override
  String get onboardingQuickStartTitle => 'You\'re Ready!';

  @override
  String get onboardingQuickStartOnline =>
      'You\'re ready to summarize text and PDFs.';

  @override
  String get onboardingQuickStartOffline =>
      'You can record meetings and use on-device transcription. Add an API key later for AI features.';

  @override
  String get onboardingGoToSettings => 'Go to Settings';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupExportTitle => 'Export Backup';

  @override
  String get backupImportTitle => 'Restore Backup';

  @override
  String get backupIncludeSettings => 'Include settings';

  @override
  String get backupIncludeApiKeys => 'Include API keys';

  @override
  String get backupIncludeApiKeysHint => 'Requires settings to be included';

  @override
  String get backupIncludeMeetings => 'Include meeting data';

  @override
  String get backupIncludeAudio => 'Include audio files';

  @override
  String get backupIncludeAudioHint => 'Significantly increases file size';

  @override
  String get backupFilename => 'Filename';

  @override
  String get backupExportButton => 'Export';

  @override
  String get backupSelectFile => 'Select Backup File';

  @override
  String get backupImportHint =>
      'Select a .summsumm backup file to restore your data. Existing meetings will be skipped (not overwritten).';

  @override
  String get backupSetPassword => 'Set Backup Password';

  @override
  String get backupEnterPassword => 'Enter Backup Password';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordHint => 'Min 8 characters';

  @override
  String get backupPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get backupImportSuccess => 'Import successful';

  @override
  String backupMeetingsImported(int count) {
    return 'Meetings imported: $count';
  }

  @override
  String backupMeetingsSkipped(int count) {
    return 'Meetings skipped: $count';
  }

  @override
  String backupSettingsRestored(String value) {
    return 'Settings restored: $value';
  }

  @override
  String backupApiKeysRestored(String value) {
    return 'API keys restored: $value';
  }

  @override
  String get backupYes => 'Yes';

  @override
  String get backupNo => 'No';

  @override
  String backupExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String backupImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String backupImportedMeetings(int imported, int skipped) {
    return 'Imported $imported meetings, skipped $skipped duplicates.';
  }

  @override
  String get settingsAiModelsSection => 'AI & Models';

  @override
  String get settingsTranscriptionSection => 'Transcription';

  @override
  String get settingsOutputSection => 'Output';

  @override
  String get settingsAppSection => 'App';

  @override
  String get settingsAiModelsRow => 'AI & Models';

  @override
  String get settingsApiConnectionRow => 'API Connection';

  @override
  String get settingsTranscriptionRow => 'Transcription';

  @override
  String get settingsSummaryLanguageRow => 'Summary & Language';

  @override
  String get settingsTtsRow => 'Text-to-Speech';

  @override
  String get settingsAppLanguageRow => 'App Language';

  @override
  String get settingsBackupRestoreRow => 'Backup & Restore';

  @override
  String get settingsConfigured => 'Configured';

  @override
  String get settingsNotConfigured => 'Not configured';

  @override
  String get settingsOnDevice => 'On-device';

  @override
  String get settingsCloud => 'Cloud';

  @override
  String get backupSettingsSection => 'Backup & Restore';

  @override
  String get backupSettingsSubtitle => 'Export or import your data';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutRow => 'About';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get aboutGitHubSubtitle => 'View source code';

  @override
  String get aboutDonate => 'Support Development';

  @override
  String get aboutDonateSubtitle => 'Buy me a coffee on Ko-fi';

  @override
  String get aboutSponsor => 'GitHub Sponsors';

  @override
  String get aboutSponsorSubtitle => 'Sponsor on GitHub';

  @override
  String get backupShare => 'Share backup file';

  @override
  String get backupSaveToDevice => 'Save to device';

  @override
  String get backupSavedToDownloads => 'Backup saved to Downloads';

  @override
  String get backupSaveFailed => 'Failed to save backup';

  @override
  String get backupModeLabel => 'How would you like to export?';

  @override
  String get backupModeShare => 'Share';

  @override
  String get backupModeSave => 'Save to Downloads';

  @override
  String get promptEditorTitle => 'Summary Prompts';

  @override
  String get defaultPromptSection => 'Default Prompt';

  @override
  String get customPromptsSection => 'Custom Prompts';

  @override
  String get summaryStyleLabel => 'Summary Style';

  @override
  String get promptTextLabel => 'Prompt Text';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get addPrompt => 'Add Prompt';

  @override
  String get noCustomPrompts => 'No custom prompts yet. Tap + to create one.';

  @override
  String get newPromptTitle => 'New Custom Prompt';

  @override
  String get editPromptTitle => 'Edit Custom Prompt';

  @override
  String get promptNameLabel => 'Name';

  @override
  String get promptNameRequired => 'Please enter a name';

  @override
  String get promptTextRequired => 'Please enter prompt text';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deletePromptTitle => 'Delete Prompt';

  @override
  String get deletePromptMessage =>
      'Are you sure you want to delete this custom prompt?';

  @override
  String get settingsSummaryRow => 'Summary';

  @override
  String get settingsPromptsRow => 'Prompts';

  @override
  String get askLibraryTitle => 'Ask Library';

  @override
  String get askLibrarySubtitle =>
      'Search and chat across indexed transcripts and documents';

  @override
  String get localLibraryChatTitle => 'Local library chat';

  @override
  String get localLibraryChatSubtitleEnabled =>
      'Ask Library indexing is enabled';

  @override
  String get localLibraryChatSubtitleDisabled =>
      'Ask Library indexing is disabled';

  @override
  String get edited => 'edited';

  @override
  String get custom => 'custom';

  @override
  String get backupNotificationPermission =>
      'Notification permission is required for backup';

  @override
  String get backupRunning => 'Backup in progress...';

  @override
  String get backupDismiss => 'Dismiss';

  @override
  String get exportSummaryPdf => 'Export Summary as PDF';

  @override
  String get exportTranscriptPdf => 'Export Transcript as PDF';

  @override
  String get notificationPermission => 'Notification permission is required';

  @override
  String get meetingDetailAudioMissing => 'Audio file missing';
}

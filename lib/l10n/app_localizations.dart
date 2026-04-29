import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// Application title shown in app bar
  ///
  /// In en, this message translates to:
  /// **'AI Text Summarizer'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Hint shown during initial setup
  ///
  /// In en, this message translates to:
  /// **'Set your API key to get started.'**
  String get settingsSetupHint;

  /// Model settings section title
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModelSection;

  /// Label for AI provider dropdown
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsProviderLabel;

  /// OpenRouter provider name
  ///
  /// In en, this message translates to:
  /// **'OpenRouter'**
  String get settingsOpenRouter;

  /// OpenAI provider name
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get settingsOpenAi;

  /// Expandable section to search all OpenRouter models
  ///
  /// In en, this message translates to:
  /// **'More models'**
  String get settingsMoreModels;

  /// Subtitle for more models section
  ///
  /// In en, this message translates to:
  /// **'Search all OpenRouter models'**
  String get settingsSearchAllModels;

  /// Message shown when API key is empty and user tries to browse models
  ///
  /// In en, this message translates to:
  /// **'Enter your API key first to load models.'**
  String get settingsEnterKeyFirst;

  /// API key section title with provider name
  ///
  /// In en, this message translates to:
  /// **'{provider} API Key'**
  String settingsApiKeySection(String provider);

  /// Label for API key input field
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get settingsApiKeyLabel;

  /// Button to save API key
  ///
  /// In en, this message translates to:
  /// **'Save Key'**
  String get settingsSaveKey;

  /// Button to test API connection
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get settingsTestButton;

  /// Success message after connection test
  ///
  /// In en, this message translates to:
  /// **'Connection successful!'**
  String get settingsConnectionSuccess;

  /// Error when testing connection without API key
  ///
  /// In en, this message translates to:
  /// **'Enter an API key first'**
  String get settingsEnterApiKeyFirst;

  /// Error when testing connection without model selected
  ///
  /// In en, this message translates to:
  /// **'Select a model first'**
  String get settingsSelectModelFirst;

  /// Summary settings section title
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get settingsSummarySection;

  /// Label for summary style dropdown
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get settingsStyleLabel;

  /// Label for summary language dropdown
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// TTS settings section title
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get settingsTtsSection;

  /// Placeholder text for advanced model search field
  ///
  /// In en, this message translates to:
  /// **'Search models...'**
  String get settingsSearchModelsHint;

  /// Error message when model list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load models: {error}'**
  String settingsFailedToLoadModels(String error);

  /// Label for UI language selector in settings
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguageLabel;

  /// Option to use device system locale
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsSystemDefault;

  /// Library screen title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// Tooltip for import file button
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get libraryImportFile;

  /// Tooltip for archived meetings button
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get libraryArchived;

  /// Tooltip for settings button
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get librarySettings;

  /// Empty state message in library
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get libraryNoItems;

  /// Error message when loading library fails
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String libraryError(String error);

  /// Snackbar message when file import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String libraryImportFailed(String error);

  /// Slidable action label for sharing a meeting
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get libraryShare;

  /// Slidable action label for renaming a meeting
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get libraryRename;

  /// Slidable action label for archiving a meeting
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get libraryArchive;

  /// Button/action label for deleting
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libraryDelete;

  /// Delete confirmation dialog title for documents
  ///
  /// In en, this message translates to:
  /// **'Delete Document?'**
  String get libraryDeleteDocument;

  /// Delete confirmation dialog title for meetings
  ///
  /// In en, this message translates to:
  /// **'Delete Meeting?'**
  String get libraryDeleteMeeting;

  /// Delete confirmation dialog content for documents
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this document summary.'**
  String get libraryDeleteDocumentConfirm;

  /// Delete confirmation dialog content for meetings
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the recording and all data.'**
  String get libraryDeleteMeetingConfirm;

  /// Cancel button label used in dialogs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Save button label used in dialogs
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// Delete button label in confirmation dialogs
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// Rename dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Meeting'**
  String get libraryRenameMeeting;

  /// Button to start summarization
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summarizeButton;

  /// Button to start transcription
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribeButton;

  /// Button to retry a failed operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// Button to redo transcription from scratch
  ///
  /// In en, this message translates to:
  /// **'Re-transcribe'**
  String get reTranscribeButton;

  /// Dialog title when confirming re-transcription
  ///
  /// In en, this message translates to:
  /// **'Replace transcript?'**
  String get reTranscribeConfirmTitle;

  /// Dialog body explaining destructive re-transcription
  ///
  /// In en, this message translates to:
  /// **'This will replace the existing transcript, diarization, and all summaries. This action cannot be undone.'**
  String get reTranscribeConfirmBody;

  /// Error indicator text in meeting tiles
  ///
  /// In en, this message translates to:
  /// **'Failed — tap for details'**
  String get libraryFailedDetails;

  /// Snackbar message after archiving a meeting
  ///
  /// In en, this message translates to:
  /// **'Meeting archived'**
  String get libraryArchivedSnackbar;

  /// Undo action in snackbar
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// Share sheet title
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTitle;

  /// Share sheet option to share audio file
  ///
  /// In en, this message translates to:
  /// **'Share Audio'**
  String get shareAudio;

  /// Share sheet option to share transcript
  ///
  /// In en, this message translates to:
  /// **'Share Transcript'**
  String get shareTranscript;

  /// Share sheet option to share summary
  ///
  /// In en, this message translates to:
  /// **'Share Summary'**
  String get shareSummary;

  /// Snackbar when audio file is missing
  ///
  /// In en, this message translates to:
  /// **'Audio file not found'**
  String get shareAudioNotFound;

  /// Tab label for summary view
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get meetingDetailTabSummary;

  /// Tab label for transcript view
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get meetingDetailTabTranscript;

  /// Tab label for chat view
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get meetingDetailTabChat;

  /// Metadata row label for meeting duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get meetingDetailDuration;

  /// Metadata row label for recording date
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get meetingDetailRecorded;

  /// Metadata row label for transcription provider
  ///
  /// In en, this message translates to:
  /// **'Transcribed by'**
  String get meetingDetailTranscribedBy;

  /// Message when meeting has no transcript yet
  ///
  /// In en, this message translates to:
  /// **'No transcript yet.\nGo to the Transcript tab to transcribe.'**
  String get meetingDetailNoTranscript;

  /// Loading text during transcription
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get meetingDetailTranscribing;

  /// Loading text during summarization
  ///
  /// In en, this message translates to:
  /// **'Summarizing…'**
  String get meetingDetailSummarizing;

  /// Fallback error text when no specific error available
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get meetingDetailErrorOccurred;

  /// Dialog title for generating a new summary
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get meetingDetailGenerateSummary;

  /// Dialog content confirming summary generation parameters
  ///
  /// In en, this message translates to:
  /// **'Generate a new summary in {language} with {style} style?'**
  String meetingDetailGenerateConfirm(String language, String style);

  /// Button to confirm summary generation
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get meetingDetailGenerate;

  /// Message in transcript tab for document-type meetings
  ///
  /// In en, this message translates to:
  /// **'This is a document, not a recording.\nGo to the Summary tab to process it.'**
  String get meetingDetailNotRecording;

  /// Tooltip explaining diarization limitation
  ///
  /// In en, this message translates to:
  /// **'Diarization requires OpenRouter'**
  String get meetingDetailDiarizationRequires;

  /// Switch label for speaker diarization
  ///
  /// In en, this message translates to:
  /// **'Diarize speakers'**
  String get meetingDetailDiarizeSpeakers;

  /// Banner text in transcript tab for document-type meetings
  ///
  /// In en, this message translates to:
  /// **'This is the imported document content, not a transcript.'**
  String get meetingDetailDocumentContent;

  /// Message in chat tab when document not yet processed
  ///
  /// In en, this message translates to:
  /// **'Document content not available yet.\nGo to the Summary tab to process it.'**
  String get meetingDetailDocumentNotReady;

  /// Message in chat tab when no transcript exists
  ///
  /// In en, this message translates to:
  /// **'Transcribe the meeting first to start chatting.'**
  String get meetingDetailTranscribeFirst;

  /// Placeholder text for chat input field
  ///
  /// In en, this message translates to:
  /// **'Ask about this meeting…'**
  String get meetingDetailChatHint;

  /// Snackbar when voice recording fails to start
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String summarySheetFailedRecording(String error);

  /// Snackbar when voice input processing fails
  ///
  /// In en, this message translates to:
  /// **'Failed to process voice input: {error}'**
  String summarySheetFailedVoice(String error);

  /// Snackbar when summary sheet starts without API key
  ///
  /// In en, this message translates to:
  /// **'No API key configured. Open Settings first.'**
  String get summarySheetNoApiKey;

  /// Snackbar after copying text
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get summarySheetCopied;

  /// Header text and button label for fact check mode
  ///
  /// In en, this message translates to:
  /// **'Fact Check'**
  String get summarySheetFactCheck;

  /// Header text for normal summary mode
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get summarySheetAiSummary;

  /// Close button tooltip in summary sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// Copy button label in summary sheet action bar
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get summarySheetCopy;

  /// TTS button label when not playing
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get summarySheetReadAloud;

  /// TTS button label when playing
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get summarySheetPause;

  /// TTS button label when paused
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get summarySheetResume;

  /// Stop TTS button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get summarySheetStop;

  /// Placeholder when only one follow-up turn remains
  ///
  /// In en, this message translates to:
  /// **'Last follow-up question...'**
  String get summarySheetLastFollowUp;

  /// Placeholder for follow-up question input
  ///
  /// In en, this message translates to:
  /// **'Ask a follow-up question...'**
  String get summarySheetFollowUpHint;

  /// Recording screen title
  ///
  /// In en, this message translates to:
  /// **'Record Meeting'**
  String get recordingTitle;

  /// Button to stop recording or TTS
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopButton;

  /// Button to start recording
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// Snackbar when microphone permission is denied
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to record'**
  String get recordingMicPermission;

  /// Snackbar when recording fails to start
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String recordingFailedStart(String error);

  /// Dialog title for enabling live transcription
  ///
  /// In en, this message translates to:
  /// **'Live Transcription'**
  String get liveTranscriptionTitle;

  /// Dialog content asking user to enable live transcription
  ///
  /// In en, this message translates to:
  /// **'Transcribe speech in real-time while recording?\n\nThis uses more battery but lets you see text appear as you speak.'**
  String get liveTranscriptionPrompt;

  /// Button to confirm enabling live transcription
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get liveTranscriptionYes;

  /// Button to decline live transcription
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get liveTranscriptionNo;

  /// Snackbar when live transcription fails to start
  ///
  /// In en, this message translates to:
  /// **'Failed to start live transcription: {error}'**
  String liveTranscriptionFailed(String error);

  /// Text for live recording indicator
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveIndicator;

  /// Archived meetings screen title
  ///
  /// In en, this message translates to:
  /// **'Archived Meetings'**
  String get archiveTitle;

  /// Error message when loading archived meetings fails
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String archiveError(String error);

  /// Empty state in archived meetings screen
  ///
  /// In en, this message translates to:
  /// **'No archived meetings'**
  String get archiveNoMeetings;

  /// Slidable action to restore archived meeting
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get archiveRestore;

  /// Snackbar after restoring a meeting
  ///
  /// In en, this message translates to:
  /// **'Meeting restored to library'**
  String get archiveRestored;

  /// Fallback title for document carousel item without title
  ///
  /// In en, this message translates to:
  /// **'Doc {index}'**
  String carouselDocFallback(int index);

  /// Fallback document title in document_title.dart
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentFallback;

  /// Summary style display name
  ///
  /// In en, this message translates to:
  /// **'Concise'**
  String get styleConcise;

  /// Summary style display name
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get styleBrief;

  /// Summary style display name
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get styleDetailed;

  /// Summary style display name
  ///
  /// In en, this message translates to:
  /// **'Structured'**
  String get styleStructured;

  /// Summary language option
  ///
  /// In en, this message translates to:
  /// **'Same as input'**
  String get langSameAsInput;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get langGerman;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get langFrench;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get langSpanish;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get langItalian;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get langPortuguese;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get langRussian;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get langChinese;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get langJapanese;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get langKorean;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get langArabic;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get langHindi;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get langDutch;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get langPolish;

  /// Language display name
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get langTurkish;

  /// Onboarding welcome screen headline
  ///
  /// In en, this message translates to:
  /// **'Summarize Anything, Anywhere'**
  String get onboardingWelcomeTitle;

  /// Onboarding welcome screen subtitle
  ///
  /// In en, this message translates to:
  /// **'AI-powered summaries from text, voice, and documents'**
  String get onboardingWelcomeSubtitle;

  /// Primary button on onboarding welcome screen
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// Skip button on onboarding screens
  ///
  /// In en, this message translates to:
  /// **'Skip Setup'**
  String get onboardingSkipSetup;

  /// Onboarding features screen title
  ///
  /// In en, this message translates to:
  /// **'What You Can Do'**
  String get onboardingFeaturesTitle;

  /// Title for online features card
  ///
  /// In en, this message translates to:
  /// **'Online Features'**
  String get onboardingOnlineFeatures;

  /// Description for online features card
  ///
  /// In en, this message translates to:
  /// **'Text summarization, PDF summaries, cloud transcription — Requires API key'**
  String get onboardingOnlineFeaturesDesc;

  /// Title for offline features card
  ///
  /// In en, this message translates to:
  /// **'Offline Features'**
  String get onboardingOfflineFeatures;

  /// Description for offline features card
  ///
  /// In en, this message translates to:
  /// **'Meeting recording, on-device transcription — Works without internet after model download'**
  String get onboardingOfflineFeaturesDesc;

  /// Note about transcription language support
  ///
  /// In en, this message translates to:
  /// **'On-device transcription supports multiple languages. Live transcription works best with English.'**
  String get onboardingTranscriptionNote;

  /// Continue button on onboarding screens
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// Onboarding API key screen title
  ///
  /// In en, this message translates to:
  /// **'Connect Your AI'**
  String get onboardingApiKeyTitle;

  /// Onboarding API key screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Add an API key to use AI-powered features. You can skip this and add it later in Settings.'**
  String get onboardingApiKeySubtitle;

  /// Skip API key setup button
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get onboardingSkipForNow;

  /// Onboarding quick start screen title
  ///
  /// In en, this message translates to:
  /// **'You\'re Ready!'**
  String get onboardingQuickStartTitle;

  /// Quick start message when API key is configured
  ///
  /// In en, this message translates to:
  /// **'You\'re ready to summarize text and PDFs.'**
  String get onboardingQuickStartOnline;

  /// Quick start message when API key was skipped
  ///
  /// In en, this message translates to:
  /// **'You can record meetings and use on-device transcription. Add an API key later for AI features.'**
  String get onboardingQuickStartOffline;

  /// Link to settings from onboarding completion
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get onboardingGoToSettings;

  /// Backup screen title
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupTitle;

  /// Export section title
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get backupExportTitle;

  /// Import section title
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get backupImportTitle;

  /// Checkbox to include settings in backup
  ///
  /// In en, this message translates to:
  /// **'Include settings'**
  String get backupIncludeSettings;

  /// Checkbox to include API keys in backup
  ///
  /// In en, this message translates to:
  /// **'Include API keys'**
  String get backupIncludeApiKeys;

  /// Subtitle explaining API keys requirement
  ///
  /// In en, this message translates to:
  /// **'Requires settings to be included'**
  String get backupIncludeApiKeysHint;

  /// Checkbox to include meeting data in backup
  ///
  /// In en, this message translates to:
  /// **'Include meeting data'**
  String get backupIncludeMeetings;

  /// Checkbox to include audio files in backup
  ///
  /// In en, this message translates to:
  /// **'Include audio files'**
  String get backupIncludeAudio;

  /// Subtitle warning about file size
  ///
  /// In en, this message translates to:
  /// **'Significantly increases file size'**
  String get backupIncludeAudioHint;

  /// Label for filename input field
  ///
  /// In en, this message translates to:
  /// **'Filename'**
  String get backupFilename;

  /// Export button label
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportButton;

  /// Import button label
  ///
  /// In en, this message translates to:
  /// **'Select Backup File'**
  String get backupSelectFile;

  /// Explanation of import behavior
  ///
  /// In en, this message translates to:
  /// **'Select a .summsumm backup file to restore your data. Existing meetings will be skipped (not overwritten).'**
  String get backupImportHint;

  /// Password dialog title for export
  ///
  /// In en, this message translates to:
  /// **'Set Backup Password'**
  String get backupSetPassword;

  /// Password dialog title for import
  ///
  /// In en, this message translates to:
  /// **'Enter Backup Password'**
  String get backupEnterPassword;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupPasswordLabel;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get backupPasswordHint;

  /// Error when password is too short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get backupPasswordTooShort;

  /// Import success header
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get backupImportSuccess;

  /// Import result line showing imported count
  ///
  /// In en, this message translates to:
  /// **'Meetings imported: {count}'**
  String backupMeetingsImported(int count);

  /// Import result line showing skipped count
  ///
  /// In en, this message translates to:
  /// **'Meetings skipped: {count}'**
  String backupMeetingsSkipped(int count);

  /// Import result line showing settings status
  ///
  /// In en, this message translates to:
  /// **'Settings restored: {value}'**
  String backupSettingsRestored(String value);

  /// Import result line showing API keys status
  ///
  /// In en, this message translates to:
  /// **'API keys restored: {value}'**
  String backupApiKeysRestored(String value);

  /// Affirmative value label
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get backupYes;

  /// Negative value label
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get backupNo;

  /// Snackbar when export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupExportFailed(String error);

  /// Snackbar when import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String backupImportFailed(String error);

  /// Success snackbar after import
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} meetings, skipped {skipped} duplicates.'**
  String backupImportedMeetings(int imported, int skipped);

  /// Settings hub section title for AI and models
  ///
  /// In en, this message translates to:
  /// **'AI & Models'**
  String get settingsAiModelsSection;

  /// Settings hub section title for transcription
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscriptionSection;

  /// Settings hub section title for output settings
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get settingsOutputSection;

  /// Settings hub section title for app settings
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsAppSection;

  /// Settings hub row title for AI models
  ///
  /// In en, this message translates to:
  /// **'AI & Models'**
  String get settingsAiModelsRow;

  /// Settings hub row title for API connection
  ///
  /// In en, this message translates to:
  /// **'API Connection'**
  String get settingsApiConnectionRow;

  /// Settings hub row title for transcription
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscriptionRow;

  /// Settings hub row title for summary and language
  ///
  /// In en, this message translates to:
  /// **'Summary & Language'**
  String get settingsSummaryLanguageRow;

  /// Settings hub row title for text-to-speech
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get settingsTtsRow;

  /// Settings hub row title for app language
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguageRow;

  /// Settings hub row title for backup and restore
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestoreRow;

  /// API key status when key is present
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get settingsConfigured;

  /// API key status when key is missing
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsNotConfigured;

  /// Transcription strategy label for on-device
  ///
  /// In en, this message translates to:
  /// **'On-device'**
  String get settingsOnDevice;

  /// Transcription strategy label for cloud
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get settingsCloud;

  /// Settings section title for backup
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupSettingsSection;

  /// Settings item subtitle for backup
  ///
  /// In en, this message translates to:
  /// **'Export or import your data'**
  String get backupSettingsSubtitle;

  /// Settings section title for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// Settings item title for about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutRow;

  /// About screen title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Version label on about screen
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// GitHub link title
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get aboutGitHub;

  /// GitHub link subtitle
  ///
  /// In en, this message translates to:
  /// **'View source code'**
  String get aboutGitHubSubtitle;

  /// Donation link title
  ///
  /// In en, this message translates to:
  /// **'Support Development'**
  String get aboutDonate;

  /// Donation link subtitle
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee on Ko-fi'**
  String get aboutDonateSubtitle;

  /// GitHub Sponsors link title
  ///
  /// In en, this message translates to:
  /// **'GitHub Sponsors'**
  String get aboutSponsor;

  /// GitHub Sponsors link subtitle
  ///
  /// In en, this message translates to:
  /// **'Sponsor on GitHub'**
  String get aboutSponsorSubtitle;

  /// Share option for backup export
  ///
  /// In en, this message translates to:
  /// **'Share backup file'**
  String get backupShare;

  /// Save option for backup export
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get backupSaveToDevice;

  /// Success message when backup saved to Downloads
  ///
  /// In en, this message translates to:
  /// **'Backup saved to Downloads'**
  String get backupSavedToDownloads;

  /// Error message when saving backup fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save backup'**
  String get backupSaveFailed;

  /// Label for backup destination picker
  ///
  /// In en, this message translates to:
  /// **'How would you like to export?'**
  String get backupModeLabel;

  /// Share mode option
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get backupModeShare;

  /// No description provided for @backupModeSave.
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get backupModeSave;

  /// Prompt editor screen title
  ///
  /// In en, this message translates to:
  /// **'Summary Prompts'**
  String get promptEditorTitle;

  /// Section title for default prompt editor
  ///
  /// In en, this message translates to:
  /// **'Default Prompt'**
  String get defaultPromptSection;

  /// Section title for custom prompts list
  ///
  /// In en, this message translates to:
  /// **'Custom Prompts'**
  String get customPromptsSection;

  /// Label for summary style dropdown
  ///
  /// In en, this message translates to:
  /// **'Summary Style'**
  String get summaryStyleLabel;

  /// Label for prompt text input field
  ///
  /// In en, this message translates to:
  /// **'Prompt Text'**
  String get promptTextLabel;

  /// Button to reset prompt to default
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// Button/label to add a custom prompt
  ///
  /// In en, this message translates to:
  /// **'Add Prompt'**
  String get addPrompt;

  /// Empty state message for custom prompts list
  ///
  /// In en, this message translates to:
  /// **'No custom prompts yet. Tap + to create one.'**
  String get noCustomPrompts;

  /// Sheet title for creating a new custom prompt
  ///
  /// In en, this message translates to:
  /// **'New Custom Prompt'**
  String get newPromptTitle;

  /// Sheet title for editing a custom prompt
  ///
  /// In en, this message translates to:
  /// **'Edit Custom Prompt'**
  String get editPromptTitle;

  /// Label for prompt name input field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get promptNameLabel;

  /// Validation error when prompt name is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get promptNameRequired;

  /// Validation error when prompt text is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter prompt text'**
  String get promptTextRequired;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Dialog title for deleting a prompt
  ///
  /// In en, this message translates to:
  /// **'Delete Prompt'**
  String get deletePromptTitle;

  /// Dialog content for deleting a prompt
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this custom prompt?'**
  String get deletePromptMessage;

  /// Settings row title for summary settings
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get settingsSummaryRow;

  /// Settings row title for prompt editor
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get settingsPromptsRow;

  /// Title for Ask Library feature
  ///
  /// In en, this message translates to:
  /// **'Ask Library'**
  String get askLibraryTitle;

  /// Subtitle describing Ask Library feature
  ///
  /// In en, this message translates to:
  /// **'Search and chat across indexed transcripts and documents'**
  String get askLibrarySubtitle;

  /// Settings row title for local library chat
  ///
  /// In en, this message translates to:
  /// **'Local library chat'**
  String get localLibraryChatTitle;

  /// Subtitle when local library chat is enabled
  ///
  /// In en, this message translates to:
  /// **'Ask Library indexing is enabled'**
  String get localLibraryChatSubtitleEnabled;

  /// Subtitle when local library chat is disabled
  ///
  /// In en, this message translates to:
  /// **'Ask Library indexing is disabled'**
  String get localLibraryChatSubtitleDisabled;

  /// Label for edited prompts count
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// Label for custom prompts count
  ///
  /// In en, this message translates to:
  /// **'custom'**
  String get custom;

  /// Message shown when notification permission is denied for backup
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required for backup'**
  String get backupNotificationPermission;

  /// Title shown while backup is running
  ///
  /// In en, this message translates to:
  /// **'Backup in progress...'**
  String get backupRunning;

  /// Button to dismiss backup dialog
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get backupDismiss;

  /// Menu item to export summary as PDF
  ///
  /// In en, this message translates to:
  /// **'Export Summary as PDF'**
  String get exportSummaryPdf;

  /// Menu item to export transcript as PDF
  ///
  /// In en, this message translates to:
  /// **'Export Transcript as PDF'**
  String get exportTranscriptPdf;

  /// Message shown when notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required'**
  String get notificationPermission;

  /// Button label when audio file is missing and cannot be transcribed
  ///
  /// In en, this message translates to:
  /// **'Audio file missing'**
  String get meetingDetailAudioMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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

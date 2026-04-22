import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'models/document.dart';
import 'theme/m3_tokens.dart';
import 'models/meeting.dart';
import 'models/summary_style.dart';
import 'providers/locale_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_sheet.dart';
import 'screens/meeting_library_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/meeting_repository.dart';
import 'utils/document_title.dart';

/// Returns true when any document is a PDF (has a content URI).
bool isDocumentShare(List<Document> documents) =>
    documents.any((d) => d.isPdf);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  // Retrieve the intent data from the native layer before the UI builds.
  const channel = MethodChannel('app.summsumm/intent');
  Map<String, dynamic>? intentData;
  String action = '';
  try {
    intentData =
        await channel.invokeMapMethod<String, dynamic>('getInitialIntent');
    action = intentData?['action'] as String? ?? '';
  } catch (_) {
    // Running in a non-Android environment or in tests
  }

  final audioDocs = <Document>[];
  final otherDocs = <Document>[];

  for (final rawDoc in (intentData?['documents'] as List<dynamic>? ?? [])) {
    final doc = rawDoc as Map<String, dynamic>;
    final text = doc['text'] as String? ?? '';
    final uri = doc['uri'] as String?;
    final name = doc['name'] as String?;
    final size = doc['size'] as int?;
    final error = doc['error'] as String?;
    final docType = doc['type'] as String?;
    final path = doc['path'] as String?;
    final durationMs = doc['durationMs'] as int?;

    if (docType == 'audio' && path != null) {
      audioDocs.add(Document(
        id: path.hashCode.toString(),
        text: '',
        title: name,
        name: name,
        size: size,
        type: 'audio',
        path: path,
        durationMs: durationMs,
      ),
      );
    } else {
      otherDocs.add(Document(
        id: (text.isNotEmpty ? text : uri ?? '').hashCode.toString(),
        text: text,
        title: name,
        uri: uri,
        name: name,
        size: size,
        error: error,
      ),
      );
    }
  }

  final repo = MeetingRepository();
  for (final audio in audioDocs) {
    final title = audio.name ?? 'Imported Audio';
    final lastDot = title.lastIndexOf('.');
    final cleanTitle = lastDot > 0 ? title.substring(0, lastDot) : title;
    final meeting = Meeting(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      durationSec: (audio.durationMs ?? 0) ~/ 1000,
      audioPath: audio.path!,
      title: cleanTitle,
      status: MeetingStatus.recorded,
      type: MeetingType.meeting,
    );
    await repo.save(meeting);
  }

  final openSettings = action == 'app.summsumm.OPEN_SETTINGS';
  final audioImported = audioDocs.isNotEmpty;
  final showOnboarding = !hasCompletedOnboarding && !openSettings && otherDocs.isEmpty;

  runApp(
    ProviderScope(
      child: SummsummApp(
        openSettings: openSettings,
        audioImported: audioImported,
        documents: otherDocs,
        showOnboarding: showOnboarding,
      ),
    ),
  );
}

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  final base = GoogleFonts.interTextTheme();
  return base.copyWith(
    displayLarge: GoogleFonts.fraunces(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displayMedium: GoogleFonts.fraunces(
      fontSize: 45,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    displaySmall: GoogleFonts.fraunces(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineLarge: GoogleFonts.fraunces(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineMedium: GoogleFonts.fraunces(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    headlineSmall: GoogleFonts.fraunces(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurface,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurface,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurface,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    ),
  );
}

class SummsummApp extends ConsumerStatefulWidget {
  const SummsummApp({
    super.key,
    required this.openSettings,
    required this.audioImported,
    required this.documents,
    required this.showOnboarding,
  });

  final bool openSettings;
  final bool audioImported;
  final List<Document> documents;
  final bool showOnboarding;

  @override
  ConsumerState<SummsummApp> createState() => _SummsummAppState();
}

class _SummsummAppState extends ConsumerState<SummsummApp> {
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsProvider.notifier).load());
    _setupNewIntentHandler();
  }

  void _setupNewIntentHandler() {
    const channel = MethodChannel('app.summsumm/intent');
    channel.setMethodCallHandler((call) async {
      if (call.method != 'onNewIntent') return;
      final rawData = call.arguments as Map<dynamic, dynamic>?;
      if (rawData == null) return;

      final audioDocs = <Document>[];
      final otherDocs = <Document>[];

      for (final rawDoc in (rawData['documents'] as List<dynamic>? ?? [])) {
        final doc = rawDoc as Map<String, dynamic>;
        final text = (doc['text'] as String?) ?? '';
        final uri = doc['uri'] as String?;
        final name = doc['name'] as String?;
        final size = doc['size'] as int?;
        final error = doc['error'] as String?;
        final docType = doc['type'] as String?;
        final path = doc['path'] as String?;
        final durationMs = doc['durationMs'] as int?;

        if (docType == 'audio' && path != null) {
          audioDocs.add(Document(
            id: path.hashCode.toString(),
            text: '',
            title: name,
            name: name,
            size: size,
            type: 'audio',
            path: path,
            durationMs: durationMs,
          ),
          );
        } else {
          otherDocs.add(Document(
            id: (text.isNotEmpty ? text : uri ?? '').hashCode.toString(),
            text: text,
            title: name,
            uri: uri,
            name: name,
            size: size,
            error: error,
          ),
          );
        }
      }

      final repo = MeetingRepository();
      for (final audio in audioDocs) {
        final title = audio.name ?? 'Imported Audio';
        final lastDot = title.lastIndexOf('.');
        final cleanTitle = lastDot > 0 ? title.substring(0, lastDot) : title;
        final meeting = Meeting(
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          durationSec: (audio.durationMs ?? 0) ~/ 1000,
          audioPath: audio.path!,
          title: cleanTitle,
          status: MeetingStatus.recorded,
          type: MeetingType.meeting,
        );
        await repo.save(meeting);
      }

      if (otherDocs.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => _SummarySheetHost(documents: otherDocs),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final lightScheme = lightDynamic ?? ColorScheme.fromSeed(
              seedColor: M3Tokens.seedColor,
              brightness: Brightness.light,
            );
            final darkScheme = darkDynamic ?? ColorScheme.fromSeed(
              seedColor: M3Tokens.seedColor,
              brightness: Brightness.dark,
            );
            return MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'AI Text Summarizer',
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('de'),
              ],
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: lightScheme,
                textTheme: _buildTextTheme(lightScheme),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                textTheme: _buildTextTheme(darkScheme),
              ),
              themeMode: ThemeMode.system,
              home: widget.showOnboarding
                  ? const OnboardingScreen()
                  : widget.openSettings
                      ? const SettingsScreen(isInitialSetup: true)
                      : widget.documents.isNotEmpty
                          ? _SummarySheetHost(documents: widget.documents)
                          : const MeetingLibraryScreen(),
            );
          },
        );
      },
    );
  }
}

/// A transparent host scaffold that immediately shows the summary bottom sheet.
/// Dismissing the sheet exits the app (returns to the calling app).
class _SummarySheetHost extends StatefulWidget {
  const _SummarySheetHost({required this.documents});

  final List<Document> documents;

  @override
  State<_SummarySheetHost> createState() => _SummarySheetHostState();
}

class _SummarySheetHostState extends State<_SummarySheetHost>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSheet());
  }

  Future<void> _showSheet() async {
    final repo = MeetingRepository();
    final title = documentTitle(widget.documents);
    final entry = Meeting(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      durationSec: 0,
      audioPath: '',
      title: title,
      transcript: widget.documents.isNotEmpty ? widget.documents.first.text : '',
      status: MeetingStatus.summarizing,
      type: MeetingType.document,
    );
    await repo.save(entry);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..forward(),
      builder: (ctx) => SummarySheet(
        documents: widget.documents,
        initialIndex: 0,
        onSummarized: (summary) async {
          await repo.save(entry.copyWith(
            summaries: [
              MeetingSummary(
                id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
                style: SummaryStyle.structured,
                language: 'Same as input',
                content: summary,
                createdAt: DateTime.now(),
              ),
            ],
            status: MeetingStatus.done,
          ),);
        },
        onSummaryFailed: (error) async {
          await repo.save(entry.copyWith(
            status: MeetingStatus.failed,
            lastError: error,
          ),);
        },
      ),
    );
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fully transparent host — only the bottom sheet is visible
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

class _DocumentSheetHost extends StatefulWidget {
  const _DocumentSheetHost({required this.documents});

  final List<Document> documents;

  @override
  State<_DocumentSheetHost> createState() => _DocumentSheetHostState();
}

class _DocumentSheetHostState extends State<_DocumentSheetHost> {
  static const double _initialSize = 0.92;

  final _dragController = DraggableScrollableController();
  double _sheetExtent = _initialSize;
  bool _sheetVisible = true;

  late final MeetingRepository _repo;
  late final Meeting _entry;

  @override
  void initState() {
    super.initState();
    _repo = MeetingRepository();
    _entry = Meeting(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      durationSec: 0,
      audioPath: '',
      title: documentTitle(widget.documents),
      transcript:
          widget.documents.isNotEmpty ? widget.documents.first.text : '',
      status: MeetingStatus.summarizing,
      type: MeetingType.document,
    );
    _repo.save(_entry);
    _dragController.addListener(_onExtentChanged);
  }

  void _onExtentChanged() {
    if (!mounted) return;
    final extent = _dragController.size;
    setState(() => _sheetExtent = extent);
    if (extent <= 0.01) setState(() => _sheetVisible = false);
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  double get _scrimOpacity =>
      (0.54 * (_sheetExtent / _initialSize)).clamp(0.0, 0.54);

  void _closeSheet() => _dragController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _sheetExtent > 0.2,
            child: const MeetingLibraryScreen(),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _scrimOpacity,
              child: const ColoredBox(
                color: Colors.black,
                child: SizedBox.expand(),
              ),
            ),
          ),
          if (_sheetVisible)
            DraggableScrollableSheet(
              controller: _dragController,
              initialChildSize: _initialSize,
              minChildSize: 0.0,
              maxChildSize: _initialSize,
              snap: true,
              snapSizes: const [0.0, _initialSize],
              builder: (ctx, scrollCtrl) => SummarySheet(
                documents: widget.documents,
                scrollController: scrollCtrl,
                onClose: _closeSheet,
                onSummarized: (summary) async {
                  await _repo.save(_entry.copyWith(
                    summaries: [
                      MeetingSummary(
                        id: 'sum_${DateTime.now().millisecondsSinceEpoch}',
                        style: SummaryStyle.structured,
                        language: 'Same as input',
                        content: summary,
                        createdAt: DateTime.now(),
                      ),
                    ],
                    status: MeetingStatus.done,
                  ),);
                },
                onSummaryFailed: (error) async {
                  await _repo.save(_entry.copyWith(
                    status: MeetingStatus.failed,
                    lastError: error,
                  ),);
                },
              ),
            ),
        ],
      ),
    );
  }
}

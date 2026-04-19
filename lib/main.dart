import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'models/document.dart';
import 'models/meeting.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_sheet.dart';
import 'screens/meeting_library_screen.dart';
import 'services/meeting_repository.dart';
import 'utils/document_title.dart';

/// Returns true when any document is a PDF (has a content URI).
bool isDocumentShare(List<Document> documents) =>
    documents.any((d) => d.isPdf);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data for intl's DateFormat — without this, non-English locales
  // throw LocaleDataException when formatting dates in meeting tiles.
  await initializeDateFormatting();

  // Retrieve the intent data from the native layer before the UI builds.
  const channel = MethodChannel('app.summsumm/intent');
  Map<String, dynamic>? intentData;
  try {
    intentData =
        await channel.invokeMapMethod<String, dynamic>('getInitialIntent');
  } catch (_) {
    // Running in a non-Android environment or in tests
  }

  final action = intentData?['action'] as String? ?? '';
  final documents =
      (intentData?['documents'] as List<dynamic>? ?? []).map((doc) {
    final text = doc['text'] as String? ?? '';
    final uri = doc['uri'] as String?;
    final name = doc['name'] as String?;
    final size = doc['size'] as int?;
    final error = doc['error'] as String?;

    return Document(
      id: (text.isNotEmpty ? text : uri ?? '').hashCode.toString(),
      text: text,
      title: name,
      uri: uri,
      name: name,
      size: size,
      error: error,
    );
  }).toList();

  final openSettings = action == 'app.summsumm.OPEN_SETTINGS';

  runApp(
    ProviderScope(
      child: SummsummApp(openSettings: openSettings, documents: documents),
    ),
  );
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colorScheme.surfaceContainerLow,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    sliderTheme: const SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 0.5,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      modalBarrierColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

class SummsummApp extends ConsumerStatefulWidget {
  const SummsummApp({
    super.key,
    required this.openSettings,
    required this.documents,
  });

  final bool openSettings;
  final List<Document> documents;

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
      final documents =
          (rawData['documents'] as List<dynamic>? ?? []).map((doc) {
        final text = (doc['text'] as String?) ?? '';
        final uri = doc['uri'] as String?;
        final name = doc['name'] as String?;
        final size = doc['size'] as int?;
        final error = doc['error'] as String?;
        return Document(
          id: (text.isNotEmpty ? text : uri ?? '').hashCode.toString(),
          text: text,
          title: name,
          uri: uri,
          name: name,
          size: size,
          error: error,
        );
      }).toList();
      if (documents.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => _SummarySheetHost(documents: documents),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'AI Text Summarizer',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
   home: widget.openSettings
           ? const SettingsScreen(isInitialSetup: true)
           : widget.documents.isNotEmpty
               ? _SummarySheetHost(documents: widget.documents)
               : const MeetingLibraryScreen(),
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
            summary: summary,
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
                    summary: summary,
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

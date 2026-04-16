import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final text = intentData?['text'] as String?;

  final openSettings = action == 'app.summsumm.OPEN_SETTINGS' || text == null;

  runApp(
    ProviderScope(
      child: SummsummApp(openSettings: openSettings, initialText: text),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    this.initialText,
  });

  final bool openSettings;
  final String? initialText;

  @override
  ConsumerState<SummsummApp> createState() => _SummsummAppState();
}

class _SummsummAppState extends ConsumerState<SummsummApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted settings on first frame
    Future.microtask(() => ref.read(settingsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Text Summarizer',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: widget.openSettings
          ? const SettingsScreen(isInitialSetup: true)
          : _SummarySheetHost(initialText: widget.initialText!),
    );
  }
}

/// A transparent host scaffold that immediately shows the summary bottom sheet.
/// Dismissing the sheet exits the app (returns to the calling app).
class _SummarySheetHost extends StatefulWidget {
  const _SummarySheetHost({required this.initialText});

  final String initialText;

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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..forward(),
      builder: (ctx) => SummarySheet(initialText: widget.initialText),
    );
    // Sheet dismissed — return to calling app
    if (mounted) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Fully transparent host — only the bottom sheet is visible
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

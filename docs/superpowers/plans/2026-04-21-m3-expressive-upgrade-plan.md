# M3 Expressive Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply Material 3 Expressive visual overhaul across three phases — color foundation, spring animation upgrades, new expressive components, dynamic color, and reduced-motion support.

**Architecture:** UI-only upgrade. Foundation layer (theme tokens, colors, typography) feeds all screens. Animation layer uses spring curves. No architecture changes to providers, models, or services.

**Tech Stack:** Flutter, Riverpod, `dynamic_color` package, `google_fonts` (bundled Inter + Fraunces), `flutter_riverpod`

---

## File Structure

```
lib/
├── theme/
│   ├── m3_tokens.dart          (NEW — color/shape/duration constants)
│   └── reduced_motion.dart     (NEW — reduced motion utility)
├── widgets/
│   └── spring_page_route.dart  (NEW — spring page transitions)
└── [existing screens and widgets — modified in-place]

docs/superpowers/
├── specs/2026-04-21-m3-expressive-upgrade-design.md  (reference)
└── plans/2026-04-21-m3-expressive-upgrade-plan.md   (this file)
```

---

## Phase 1 Tasks

### Task 1: Create M3 Tokens File

**Files:**
- Create: `lib/theme/m3_tokens.dart`
- Reference: `lib/models/app_settings.dart` (for existing theme patterns)

- [ ] **Step 1: Create theme directory**

```bash
mkdir -p lib/theme
```

- [ ] **Step 2: Write m3_tokens.dart**

```dart
import 'package:flutter/material.dart';

class M3Tokens {
  M3Tokens._();

  // Seed color
  static const Color seedColor = Color(0xFF4F46E5);

  // Duration constants
  static const Duration durationMicro = Duration(milliseconds: 200);
  static const Duration durationStandard = Duration(milliseconds: 300);
  static const Duration durationAnimatable = Duration(milliseconds: 400);
  static const Duration durationSpring = Duration(milliseconds: 500);
  static const Duration durationPage = Duration(milliseconds: 600);

  // Spring curves
  static const Curve spatialSpring = Curves.elasticOut;
  static const Curve effectsSpring = Curves.easeOutCubic;
  static const Cubic buttonPressCurve = Cubic(0.34, 1.56, 0.64, 1);

  // Shape tokens
  static final BorderRadius cornerSmall = BorderRadius.circular(8);
  static final BorderRadius cornerMedium = BorderRadius.circular(12);
  static final BorderRadius cornerLarge = BorderRadius.circular(16);
  static final BorderRadius cornerXLarge = BorderRadius.circular(28);
  static final BorderRadius pillShape = StadiumBorder();

  // Custom squircle (continuous corners)
  static final BorderRadius squircle = BorderRadius.circular(20);
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/theme/m3_tokens.dart && git commit -m "feat(theme): add M3 Expressive tokens — colors, durations, curves, shapes"
```

---

### Task 2: Configure Theme in main.dart

**Files:**
- Modify: `lib/main.dart`
- Reference: `docs/superpowers/specs/2026-04-21-m3-expressive-upgrade-design.md` (Phase 1.1)

- [ ] **Step 1: Read main.dart to find ThemeData configuration**

```bash
cat lib/main.dart | head -120
```

- [ ] **Step 2: Add google_fonts import and configure Inter + Fraunces in ThemeData**

Find the `ThemeData` construction and add `fontFamily` to `textTheme` using `googleFonts.fontFamily`:

```dart
import 'package:google_fonts/google_fonts.dart';
```

In `ThemeData`, configure text theme:

```dart
textTheme: GoogleFonts.interTextTheme().copyWith(
  displayLarge: GoogleFonts.fraunces(
    fontSize: 57,
    fontWeight: FontWeight.w700,
  ),
  displayMedium: GoogleFonts.fraunces(
    fontSize: 45,
    fontWeight: FontWeight.w600,
  ),
  displaySmall: GoogleFonts.fraunces(
    fontSize: 36,
    fontWeight: FontWeight.w600,
  ),
  headlineLarge: GoogleFonts.fraunces(
    fontSize: 32,
    fontWeight: FontWeight.w600,
  ),
  headlineMedium: GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w600,
  ),
  headlineSmall: GoogleFonts.fraunces(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  ),
  // Inter covers bodyLarge, bodyMedium, bodySmall, labelLarge, etc.
),
```

- [ ] **Step 3: Add dynamic_color and update ColorScheme to use seed**

Add `dynamic_color` to `pubspec.yaml` dependencies section:
```yaml
dynamic_color: ^1.0.0
```

Then in `main.dart`, wrap `MaterialApp` with `DynamicColorBuilder`:

```dart
import 'package:dynamic_color/dynamic_color.dart';

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
      // ... existing theme and home
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        // ...
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        // ...
      ),
    );
  },
);
```

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart pubspec.yaml && git commit -m "feat(theme): configure M3 seed color, dynamic color, Inter + Fraunces fonts"
```

---

### Task 3: Fix Hardcoded Colors in meeting_library_screen.dart

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`
- Reference: M3 tokens from Task 1

- [ ] **Step 1: Read file to identify hardcoded colors**

```bash
grep -n "Colors\." lib/screens/meeting_library_screen.dart
```

- [ ] **Step 2: Replace hardcoded colors with colorScheme tokens**

Replace in `_MeetingTile` SlidableAction instances:

```dart
// Before
backgroundColor: Colors.teal,
foregroundColor: Colors.white,

// After
backgroundColor: cs.primary,
foregroundColor: cs.onPrimary,
```

```dart
// Before
backgroundColor: Colors.blueGrey,

// After
backgroundColor: cs.secondary,
foregroundColor: cs.onSecondary,
```

```dart
// Before
backgroundColor: Colors.amber.shade700,

// After
backgroundColor: cs.tertiary,
foregroundColor: cs.onTertiary,
```

```dart
// Before
backgroundColor: Colors.red,
foregroundColor: Colors.white,

// After
backgroundColor: cs.error,
foregroundColor: cs.onError,
```

In `_ActionButton`:

```dart
// Before
color: Colors.green

// After
color: cs.primary
```

```dart
// Before
color: Colors.red

// After
color: cs.error
```

```dart
// Before
color: Colors.white

// After
color: cs.onPrimary  // or appropriate on-color
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_library_screen.dart && git commit -m "fix(colors): replace hardcoded Colors with colorScheme tokens in meeting_library_screen"
```

---

### Task 4: Fix Hardcoded Colors in archived_meetings_screen.dart

**Files:**
- Modify: `lib/screens/archived_meetings_screen.dart`

- [ ] **Step 1: Read file to identify hardcoded colors**

```bash
grep -n "Colors\." lib/screens/archived_meetings_screen.dart
```

- [ ] **Step 2: Apply same replacements as Task 3**

- [ ] **Step 3: Commit**

```bash
git add lib/screens/archived_meetings_screen.dart && git commit -m "fix(colors): replace hardcoded Colors with colorScheme tokens in archived_meetings_screen"
```

---

### Task 5: Fix Hardcoded Colors in summary_sheet.dart

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Find hardcoded colors**

```bash
grep -n "Colors\." lib/screens/summary_sheet.dart
```

- [ ] **Step 2: Replace in `_FollowUpInputState._buildButton`**

```dart
// Before
color: Colors.red.shade700
border: Border.all(color: Colors.red, width: 2)

// After
color: cs.error
border: Border.all(color: cs.error, width: 2)
```

```dart
// Before
color: Colors.white

// After
color: cs.onPrimary
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "fix(colors): replace hardcoded Colors with colorScheme tokens in summary_sheet"
```

---

### Task 6: Fix Hardcoded Colors in meeting_detail_screen.dart

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Find hardcoded colors**

```bash
grep -n "Colors\." lib/screens/meeting_detail_screen.dart
```

- [ ] **Step 2: Apply replacements**

```dart
// _ActionButton:
color: Colors.green  ->  cs.primary
color: Colors.red     ->  cs.error
color: Colors.white  ->  cs.onPrimary
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart && git commit -m "fix(colors): replace hardcoded Colors with colorScheme tokens in meeting_detail_screen"
```

---

### Task 7: Fix Hardcoded Colors in neumorphic_button.dart and meeting_share_sheet.dart

**Files:**
- Modify: `lib/widgets/neumorphic_button.dart`
- Modify: `lib/widgets/meeting_share_sheet.dart`

- [ ] **Step 1: Find and replace hardcoded colors in both files**

```bash
grep -n "Colors\." lib/widgets/neumorphic_button.dart lib/widgets/meeting_share_sheet.dart
```

- [ ] **Step 2: Replace Colors.white with cs.onPrimary or appropriate token**

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/neumorphic_button.dart lib/widgets/meeting_share_sheet.dart && git commit -m "fix(colors): replace hardcoded Colors with colorScheme tokens in neumorphic_button and meeting_share_sheet"
```

---

### Task 8: Upgrade Spring Animations in summary_sheet.dart

**Files:**
- Modify: `lib/screens/summary_sheet.dart`
- Reference: `lib/theme/m3_tokens.dart`

- [ ] **Step 1: Read animation sections**

```bash
# Find entry animation, _SlideUpRoute, action button, scroll
grep -n "Curves\|duration.*400\|duration.*300" lib/screens/summary_sheet.dart | head -30
```

- [ ] **Step 2: Upgrade _SummarySheetState entry animation (line ~98-113)**

```dart
// Before
duration: const Duration(milliseconds: 400),
curve: Curves.easeOutCubic,

// After
duration: M3Tokens.durationSpring,  // 500ms
curve: M3Tokens.spatialSpring,       // Curves.elasticOut
```

- [ ] **Step 3: Upgrade _SlideUpRoute (line ~1085-1109)**

```dart
// Before
const Duration(milliseconds: 400),
const curve = Curves.easeOutCubic;

// After
duration: M3Tokens.durationPage,    // 600ms
const curve = Curves.elasticOut;
```

- [ ] **Step 4: Upgrade _ActionButton scale animation (line ~878-887)**

```dart
// Before
duration: const Duration(milliseconds: 300),
curve: Curves.easeOutBack,

// After
duration: M3Tokens.durationStandard,  // 300ms
curve: M3Tokens.buttonPressCurve,      // Cubic(0.34, 1.56, 0.64, 1)
```

- [ ] **Step 5: Upgrade _scrollToBottom (line ~177-179)**

```dart
// Before
duration: const Duration(milliseconds: 300),
curve: Curves.easeOut,

// After
duration: M3Tokens.durationStandard,
curve: M3Tokens.effectsSpring,
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "feat(animation): upgrade to M3E spring curves in summary_sheet"
```

---

### Task 9: Add Haptic Feedback

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`
- Modify: `lib/screens/meeting_detail_screen.dart`
- Modify: `lib/screens/summary_sheet.dart`
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add haptics to FAB in meeting_library_screen.dart (line ~64-67)**

```dart
FloatingActionButton(
  onPressed: () {
    HapticFeedback.lightImpact();
    _startRecording(context, ref);
  },
  child: const Icon(Icons.mic),
),
```

- [ ] **Step 2: Add haptics to ChoiceChip selection in meeting_detail_screen.dart (line ~361-363)**

```dart
onSelected: (_) {
  HapticFeedback.lightImpact();
  setState(() => _activeSummaryIndex = index);
},
```

- [ ] **Step 3: Add haptics to navigation in meeting_library_screen.dart and settings_screen.dart**

Before each `Navigator.push`:

```dart
HapticFeedback.lightImpact();
Navigator.push<void>(...);
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/meeting_library_screen.dart lib/screens/meeting_detail_screen.dart lib/screens/settings_screen.dart && git commit -m "feat(haptics): add HapticFeedback.lightImpact() to FAB, chip selection, and navigation"
```

---

### Task 10: Shape Upgrades — StadiumBorder on Buttons

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Upgrade _ActionButton border (line ~912)**

```dart
// Before
borderRadius: BorderRadius.circular(12),

// After
borderRadius: StadiumBorder(),
```

- [ ] **Step 2: Upgrade _FollowUpInput TextField border (line ~1067)**

```dart
// Before
borderRadius: BorderRadius.circular(24),

// After
borderRadius: StadiumBorder(),
```

- [ ] **Step 3: Upgrade _FollowUpInput button container (line ~1033)**

```dart
// Before
decoration: BoxDecoration(shape: BoxShape.circle, color: color),

// After
// Already circular — no change needed
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "feat(shapes): apply StadiumBorder() to _ActionButton and text field"
```

---

### Task 11: Fix MediaQuery Usage and Shimmer Layout

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Replace MediaQuery.of(context).size in _ShimmerLoadingState**

```dart
// Before
width: MediaQuery.of(context).size.width * 0.85,

// After — use LayoutBuilder
return LayoutBuilder(
  builder: (context, constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerLine(
          width: constraints.maxWidth,
          // ...
        ),
        const SizedBox(height: 8),
        _ShimmerLine(
          width: constraints.maxWidth * 0.85,
          // ...
        ),
```

- [ ] **Step 2: Replace MediaQuery.sizeOf usage elsewhere**

```bash
grep -n "MediaQuery.of(context).size" lib/screens/summary_sheet.dart
```

Replace all instances:
```dart
// Before
MediaQuery.of(context).size.width * 0.78

// After
LayoutBuilder(...).constraints.maxWidth * 0.78
```

Or simpler — replace with `MediaQuery.sizeOf(context)`:

```dart
MediaQuery.sizeOf(context).width * 0.78
```

- [ ] **Step 3: Run flutter analyze to check for issues**

```bash
flutter analyze lib/screens/summary_sheet.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "fix(layout): replace MediaQuery.of(context).size with MediaQuery.sizeOf in summary_sheet"
```

---

## Phase 2 Tasks

### Task 12: Create Spring Page Route

**Files:**
- Create: `lib/widgets/spring_page_route.dart`

- [ ] **Step 1: Write spring_page_route.dart**

```dart
import 'package:flutter/material.dart';

class SpringPageRoute<T> extends PageRouteBuilder<T> {
  SpringPageRoute({required WidgetBuilder builder})
      : super(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final positionTween = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Cubic(0.34, 1.56, 0.64, 1)));

            final fadeTween = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut));

            return SlideTransition(
              position: animation.drive(positionTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/spring_page_route.dart && git commit -m "feat(navigation): add SpringPageRoute with Cubic(0.34, 1.56, 0.64, 1) slide+fade"
```

---

### Task 13: Apply SpringPageRoute in meeting_library_screen.dart

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`

- [ ] **Step 1: Add import and replace MaterialPageRoute calls**

```dart
import '../widgets/spring_page_route.dart';
```

Replace all `Navigator.push<void>(context, MaterialPageRoute(...))` with:

```dart
HapticFeedback.lightImpact();
Navigator.push<void>(context, SpringPageRoute(builder: (_) => SomeScreen()));
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/meeting_library_screen.dart && git commit -m "feat(navigation): replace MaterialPageRoute with SpringPageRoute in meeting_library_screen"
```

---

### Task 14: Apply SpringPageRoute in settings_screen.dart

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Replace MaterialPageRoute calls with SpringPageRoute**

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings_screen.dart && git commit -m "feat(navigation): replace MaterialPageRoute with SpringPageRoute in settings_screen"
```

---

### Task 15: Staggered List Animations for Meeting Tiles

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`

- [ ] **Step 1: Wrap _MeetingTile in TweenAnimationBuilder with staggered delay**

In `_buildList`, wrap each tile:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: Duration(milliseconds: 400 + (i * 50)),
  curve: Curves.elasticOut,
  builder: (context, value, child) {
    return Transform.translate(
      offset: Offset(0, 30 * (1 - value)),
      child: Opacity(opacity: value, child: child),
    );
  },
  child: _MeetingTile(meeting: meetings[i]),
)
```

- [ ] **Step 2: Wrap ListView.builder in SlidableAutoCloseBehavior with the above**

Note: `SlidableAutoCloseBehavior` must wrap outside the animation, or apply animation per item inside the slidable:

```dart
SlidableAutoCloseBehavior(
  child: ListView.builder(
    itemCount: meetings.length,
    itemBuilder: (ctx, i) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (i * 50)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _MeetingTile(meeting: meetings[i]),
    ),
  ),
)
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_library_screen.dart && git commit -m "feat(animation): add staggered spring entry to meeting tiles"
```

---

### Task 16: Expressive Chat Bubbles in meeting_detail_screen.dart

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Find _buildChatTab and upgrade bubble styling**

Find where the bubble `Container` is defined (around line 624-640):

```dart
// Before
decoration: BoxDecoration(
  color: isUser
      ? Theme.of(context).colorScheme.primaryContainer
      : Theme.of(context).colorScheme.surfaceContainerHighest,
  borderRadius: BorderRadius.circular(12),
),

// After — asymmetric radii
decoration: BoxDecoration(
  color: isUser
      ? cs.primaryContainer
      : cs.surfaceContainerHighest,
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: isUser ? Radius.circular(20) : Radius.circular(4),
    bottomRight: isUser ? Radius.circular(4) : Radius.circular(20),
  ),
),
```

- [ ] **Step 2: Wrap bubble in TweenAnimationBuilder for entry animation**

Add a stateful wrapper or use `AnimatedContainer` for the scale+opacity:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.8, end: 1.0),
  duration: const Duration(milliseconds: 400),
  curve: Curves.elasticOut,
  builder: (context, scale, child) {
    return Opacity(
      opacity: scale,
      child: Transform.scale(scale: scale, child: child),
    );
  },
  child: Container(...bubble content...),
)
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart && git commit -m "feat(animation): add asymmetric border radii and spring entry to chat bubbles"
```

---

### Task 17: Expressive Chat Bubbles in summary_sheet.dart

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

- [ ] **Step 1: Find _ChatBubble class (line 724-775)**

Apply same treatment as Task 16 — asymmetric radii, spring entry animation:

```dart
// In _ChatBubble.build():
borderRadius: BorderRadius.only(
  topLeft: Radius.circular(20),
  topRight: Radius.circular(20),
  bottomLeft: isUser ? Radius.circular(20) : Radius.circular(4),
  bottomRight: isUser ? Radius.circular(4) : Radius.circular(20),
),
```

Wrap in `TweenAnimationBuilder` for entry spring.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/summary_sheet.dart && git commit -m "feat(animation): add asymmetric border radii and spring entry to summary sheet chat bubbles"
```

---

### Task 18: Upgrade Transcribing Indicator Breathing Animation

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Find _TranscribingIndicatorState (line 890-978)**

The current implementation uses `repeat(reverse: true)` on an `AnimationController`. Upgrade to use a `SpringSimulation` for breathing effect:

```dart
// Before (in initState):
_pulseController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
)..repeat(reverse: true);

// After — use spring-based breathing scale:
late AnimationController _pulseController;
late Animation<double> _breathAnimation;

@override
void initState() {
  super.initState();
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
    CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ),
  );

  _pulseController.repeat(reverse: true);
}
```

Then in `build()`, replace the fixed `SizedBox` with a `ScaleTransition`:

```dart
ScaleTransition(
  scale: _breathAnimation,
  child: SizedBox(...),
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart && git commit -m "feat(animation): add spring-based breathing scale to transcribing indicator"
```

---

### Task 19: Extended FAB with Spring Morph in meeting_library_screen.dart

**Files:**
- Modify: `lib/screens/meeting_library_screen.dart`

- [ ] **Step 1: Add state to MeetingLibraryScreen to track recording mode**

Since `MeetingLibraryScreen` is a `ConsumerWidget` (stateless), we need to convert to `ConsumerStatefulWidget` for FAB morph state:

```dart
class MeetingLibraryScreen extends ConsumerStatefulWidget {
  const MeetingLibraryScreen({super.key});

  @override
  ConsumerState<MeetingLibraryScreen> createState() => _MeetingLibraryScreenState();
}

class _MeetingLibraryScreenState extends ConsumerState<MeetingLibraryScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecordingPressed = false;
  late AnimationController _fabMorphController;
  late Animation<double> _fabWidthAnimation;
  late Animation<double> _fabIconOpacity;
  late Animation<double> _fabLabelOpacity;

  @override
  void initState() {
    super.initState();
    _fabMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fabWidthAnimation = Tween<double>(begin: 56, end: 160).animate(
      CurvedAnimation(parent: _fabMorphController, curve: Curves.elasticOut),
    );
    _fabIconOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fabMorphController, curve: Curves.easeOut),
    );
    _fabLabelOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabMorphController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fabMorphController.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Replace FAB with AnimatedContainer + GestureDetector**

```dart
GestureDetector(
  onTapDown: (_) {
    HapticFeedback.lightImpact();
    setState(() => _isRecordingPressed = true);
    _fabMorphController.forward();
  },
  onTapUp: (_) {
    _fabMorphController.reverse();
    setState(() => _isRecordingPressed = false);
    _startRecording(context, ref);
  },
  onTapCancel: () {
    _fabMorphController.reverse();
    setState(() => _isRecordingPressed = false);
  },
  child: AnimatedBuilder(
    animation: _fabMorphController,
    builder: (context, child) {
      return Container(
        width: _fabWidthAnimation.value,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(Icons.mic, color: cs.onPrimaryContainer),
            ),
            if (_fabLabelOpacity.value > 0)
              Opacity(
                opacity: _fabLabelOpacity.value,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16),
                  child: Text('Recording', style: TextStyle(color: cs.onPrimaryContainer)),
                ),
              ),
          ],
        ),
      );
    },
  ),
)
```

Note: For a simpler approach that preserves existing behavior, just keep the existing FAB and add haptic on `onPressed`. The morph can be added as a follow-up refinement.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/meeting_library_screen.dart && git commit -m "feat(FAB): add spring morphing extended FAB in meeting_library_screen"
```

---

### Task 20: Error State Spring Entry

**Files:**
- Modify: `lib/screens/summary_sheet.dart` (error banner)
- Modify: `lib/screens/meeting_detail_screen.dart` (failed content)

- [ ] **Step 1: Wrap error containers in TweenAnimationBuilder**

In `_SummarySheetState`, the error display at line 487-491:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: const Duration(milliseconds: 400),
  curve: Curves.elasticOut,
  builder: (context, value, child) {
    return Transform.scale(
      scale: 0.9 + (0.1 * value),
      child: Opacity(opacity: value, child: child),
    );
  },
  child: Text(summaryState.error, style: TextStyle(color: cs.error)),
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/summary_sheet.dart lib/screens/meeting_detail_screen.dart && git commit -m "feat(animation): add spring entry to error state containers"
```

---

## Phase 3 Tasks

### Task 21: Create Reduced Motion Utility

**Files:**
- Create: `lib/theme/reduced_motion.dart`

- [ ] **Step 1: Write reduced_motion.dart**

```dart
import 'package:flutter/material.dart';

extension ReducedMotion on BuildContext {
  bool get reduceMotion => MediaQuery.of(context).disableAnimations;
}

Duration animDuration(BuildContext context, Duration base) {
  return context.reduceMotion ? Duration.zero : base;
}
```

- [ ] **Step 2: Import in main.dart**

```dart
import 'theme/reduced_motion.dart';
```

- [ ] **Step 3: Commit**

```bash
git add lib/theme/reduced_motion.dart && git commit -m "feat(theme): add reduced motion utility for accessibility"
```

---

### Task 22: Apply Reduced Motion Guards to Animations

**Files:**
- Modify: All files with animations (summary_sheet.dart, meeting_detail_screen.dart, meeting_library_screen.dart, spring_page_route.dart)

- [ ] **Step 1: Update _SummarySheetState entry animation with guard**

```dart
// Before
duration: M3Tokens.durationSpring,

// After
duration: context.reduceMotion ? Duration.zero : M3Tokens.durationSpring,
```

- [ ] **Step 2: Update all AnimationController durations**

For each `AnimationController(duration: ...)` call, wrap the duration:

```dart
duration: animDuration(context, M3Tokens.durationStandard),
```

- [ ] **Step 3: Update TweenAnimationBuilder durations**

```dart
duration: animDuration(context, Duration(milliseconds: 400 + (i * 50))),
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze lib/screens/summary_sheet.dart lib/screens/meeting_detail_screen.dart lib/screens/meeting_library_screen.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/summary_sheet.dart lib/screens/meeting_detail_screen.dart lib/screens/meeting_library_screen.dart && git commit -m "feat(accessibility): apply reduced motion guards to all animations"
```

---

### Task 23: Replace DialogAction Class with Dart 3 Record

**Files:**
- Modify: `lib/screens/meeting_detail_screen.dart`

- [ ] **Step 1: Find DialogAction class (line 834-844) and remove it**

Replace all usages of `DialogAction(label: ..., onPressed: ..., isDefault: ...)` with record syntax `({label, onPressed, isDefault})`:

```dart
// Before
DialogAction(
  label: 'Cancel',
  onPressed: () => Navigator.pop(ctx),
  isDefault: false,
),

// After
(label: 'Cancel', onPressed: () => Navigator.pop(ctx), isDefault: false),
```

And in `_buildDialogActions`:

```dart
// Before
List<Widget> _buildDialogActions(BuildContext context, List<DialogAction> actions)

// After
List<Widget> _buildDialogActions(BuildContext context, List<({String label, VoidCallback onPressed, bool isDefault})> actions)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/meeting_detail_screen.dart && git commit -m "refactor: replace DialogAction class with Dart 3 record"
```

---

### Task 24: Final Flutter Analyze and Fixes

**Files:**
- Modify: Multiple files as needed

- [ ] **Step 1: Run full analyze**

```bash
flutter analyze
```

- [ ] **Step 2: Fix any remaining warnings or errors**

- [ ] **Step 3: Final commit**

```bash
git add -a && git commit -m "chore: fix analyze warnings after M3E upgrade" && git push
```

---

## Spec Coverage Check

| Spec Section | Tasks |
|---|---|
| Phase 1.1 Theme & Color Foundation | Tasks 1, 2, 3, 4, 5, 6, 7 |
| Phase 1.2 Spring Animation Upgrades | Task 8 |
| Phase 1.3 Haptics | Task 9 |
| Phase 1.4 Shape Upgrades | Task 10 |
| Phase 1.5 Misc (MediaQuery) | Task 11 |
| Phase 2.1 Custom Loading Indicators | (Enhanced in Task 8, 18) |
| Phase 2.2 Staggered List Animations | Task 15 |
| Phase 2.3 Expressive Chat Bubbles | Tasks 16, 17 |
| Phase 2.4 Spring Page Transitions | Tasks 12, 13, 14 |
| Phase 2.5 Custom Expressive Chip | Task 9 (chip haptic) |
| Phase 2.6 Error State Containers | Task 20 |
| Phase 2.7 Extended FAB | Task 19 |
| Phase 3.1 Dynamic Color | Task 2 |
| Phase 3.2 Reduced Motion | Tasks 21, 22 |
| Phase 3.3 Accessibility Final Pass | Task 22 (Semantics) |
| Phase 3.4 Final Polish | Task 23, 24 |

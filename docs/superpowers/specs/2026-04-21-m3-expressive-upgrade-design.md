# M3 Expressive Upgrade — Design Spec

**Date**: 2026-04-21
**Project**: summsumm Flutter App
**Scope**: Material 3 Expressive visual overhaul

---

## Overview

Full Material 3 Expressive overhaul of the summsumm app. Three delivery phases that ship visible improvements incrementally.

**Guiding principles:**
- Balanced spring physics: `Curves.elasticOut` / `Cubic(0.34, 1.56, 0.64, 1)`
- Seed-color theming with Material You dynamic color support
- Inter (workhorse) + Fraunces (display) font pairing
- No architecture changes — UI-only upgrade
- Every phase ships visible improvements

---

## Design Decisions

### Motion
- Spring curve: `Curves.elasticOut` for spatial/movement; `Curves.easeOutCubic` for effects
- Custom cubic: `Cubic(0.34, 1.56, 0.64, 1)` for button press scales
- Standard durations: 300ms (micro), 500ms (standard), 600ms (dramatic)
- Reduced motion: all animations guard with `MediaQuery.disableAnimations`

### Color
- Seed color: deep indigo (`Color(0xFF4F46E5)`)
- Generated via `ColorScheme.fromSeed(seedColor, brightness)`
- Dynamic color via `dynamic_color` package with fallback to seed
- All hardcoded colors replaced with `colorScheme` tokens
- Color tokens extracted to `lib/theme/m3_tokens.dart`

### Typography
- Inter (400, 500, 600) for body, labels, UI
- Fraunces (600, 700) for display/headlines
- Bundled via `google_fonts` with `bundless: false` (prevention of runtime fetch)

### Shapes
- `StadiumBorder()` for buttons, pill text fields, action indicators
- Expressive bubbles: asymmetric radii `(20, 20, 4, 20)` user / `(20, 20, 20, 4)` AI
- Squircle containers for section cards
- M3 corner token scale: 4dp–28dp–100%

### Haptics
- Primary actions: `HapticFeedback.lightImpact()`
- Secondary actions: `HapticFeedback.selectionClick()`
- Navigation transitions: `HapticFeedback.lightImpact()`

---

## Phase 1: Quick Wins — Foundation + Existing Component Upgrade

**Goal**: Fix dark mode breakage, improve animation feel, lay groundwork.

### 1.1 Theme & Color Foundation
- **File**: `lib/theme/m3_tokens.dart` (new)
  - Export M3 color tokens, shape tokens, duration constants
- **File**: `lib/main.dart`
  - Configure `ThemeData` with `ColorScheme.fromSeed`
  - Set `googleFonts` font family to Inter + Fraunces
  - Wrap app with `DynamicColorBuilder`
- **File**: `lib/screens/meeting_library_screen.dart`
  - Replace: `Colors.teal` → `cs.primary`, `Colors.blueGrey` → `cs.secondary`, `Colors.amber.shade700` → `cs.tertiary`, `Colors.red` → `cs.error`, `Colors.white` → `cs.onPrimary`/`cs.onError`, `Colors.green` → `cs.primary`
- **File**: `lib/screens/archived_meetings_screen.dart`
  - Same hardcoded color replacements
- **File**: `lib/screens/summary_sheet.dart`
  - Replace: `Colors.red.shade700` → `cs.error`, `Colors.red` → `cs.error`, `Colors.white` → `cs.onPrimary`/`cs.onError`
- **File**: `lib/screens/meeting_detail_screen.dart`
  - Replace: `Colors.green` → `cs.primary`, `Colors.red` → `cs.error`, `Colors.white` → `cs.onPrimary`/`cs.onError`
- **File**: `lib/widgets/neumorphic_button.dart`
  - Replace: `Colors.white` → `cs.onPrimary` or appropriate token
- **File**: `lib/widgets/meeting_share_sheet.dart`
  - Review and replace any hardcoded colors

### 1.2 Spring Animation Upgrades
- **File**: `lib/screens/summary_sheet.dart`
  - `_SummarySheetState` entry animation: `Curves.easeOutCubic` → `Curves.elasticOut`, 400ms → 500ms
  - `_SlideUpRoute`: `Curves.easeOutCubic` → `Curves.elasticOut`, 400ms → 600ms
  - `_ActionButton` scale: `Curves.easeOutBack` → `Cubic(0.34, 1.56, 0.64, 1)`, 300ms
  - Scroll animation: `Curves.easeOut` → `Curves.easeOutCubic`
- **File**: `lib/main.dart`
  - Dialog transitions: upgrade to spring curves
- **File**: `lib/screens/meeting_detail_screen.dart`
  - `_TranscribingIndicator` pulse: add spring-based breathing animation
  - `AnimatedSwitcher` duration upgrade: 300ms → 400ms with `Curves.easeOutCubic`

### 1.3 Haptics
- **File**: `lib/screens/meeting_library_screen.dart`
  - FAB press: `HapticFeedback.lightImpact()` on `onPressed`
- **File**: `lib/screens/meeting_library_screen.dart` and `lib/screens/settings_screen.dart`
  - Navigation push: `HapticFeedback.lightImpact()` before `Navigator.push`
- **File**: `lib/screens/meeting_detail_screen.dart`
  - `ChoiceChip` selection: `HapticFeedback.lightImpact()` in `onSelected`
  - `Switch` for diarize: already system-provided
- **File**: `lib/screens/summary_sheet.dart`
  - Slidable actions: add `HapticFeedback.selectionClick()` to action handlers

### 1.4 Shape Upgrades
- **File**: `lib/screens/summary_sheet.dart`
  - `_ActionButton`: `BorderRadius.circular(12)` → `StadiumBorder()`
  - `_FollowUpInput` TextField: `BorderRadius.circular(24)` → `StadiumBorder()`
- **File**: `lib/screens/meeting_library_screen.dart`
  - FAB: upgrade to **Extended FAB pattern** — shows label "Record" with spring morph on long press
- **File**: `lib/widgets/glass_card.dart`
  - Optional: subtle squircle via `BorderRadius.circular(20)` (already close)

### 1.5 Misc Fixes
- Replace 6× `MediaQuery.of(context).size` → `MediaQuery.sizeOf(context)` (or `LayoutBuilder` where appropriate)
- **File**: `lib/screens/summary_sheet.dart`
  - `_ShimmerLoading`: replace `MediaQuery.of(context).size.width * 0.85` with `LayoutBuilder`

---

## Phase 2: New Expressive Components

**Goal**: Add components that give the app its premium, expressive character.

### 2.1 Custom Loading Indicators
- **File**: `lib/screens/summary_sheet.dart`
  - `_ShimmerLoading`: enhance with multi-line wavy shimmer using stacked gradients with phase-shifted animations
  - Add spring-based breathing to shimmer line reveal
- **File**: `lib/screens/meeting_detail_screen.dart`
  - `_TranscribingIndicator`: spring-based breathing scale (1.0 → 1.05 → 1.0) using `SpringSimulation`

### 2.2 Staggered List Animations
- **File**: `lib/screens/meeting_library_screen.dart`
  - `_MeetingTile`: staggered entry using `TweenAnimationBuilder` with `Curves.elasticOut`, 50ms delay per item, vertical offset 30dp → 0
- Use `WidgetsBinding.instance.addPostFrameCallback` to trigger on first build only

### 2.3 Expressive Chat Bubbles
- **File**: `lib/screens/meeting_detail_screen.dart`
  - Chat bubbles: asymmetric radii — `(20, 20, 4, 20)` user, `(20, 20, 20, 4)` AI
  - Entry animation: spring scale + fade (scale 0.8 → 1.0, opacity 0 → 1, 400ms `elasticOut`)
- **File**: `lib/screens/summary_sheet.dart`
  - `_ChatBubble`: same treatment

### 2.4 Spring Page Transitions
- **File**: `lib/widgets/spring_page_route.dart` (new)
  - `SpringPageRoute<T>` extending `PageRouteBuilder`
  - Position: `Cubic(0.34, 1.56, 0.64, 1)` for slide
  - Opacity: `Curves.easeOut` for fade
  - Duration: 600ms
- **File**: `lib/screens/meeting_library_screen.dart`
  - Replace `MaterialPageRoute` with `SpringPageRoute` for: settings, meeting detail, recording, archived
- **File**: `lib/screens/settings_screen.dart`
  - Same replacement for push to meeting detail

### 2.5 Custom Expressive Chip
- **File**: `lib/screens/meeting_detail_screen.dart`
  - `_buildChipRow` ChoiceChip: spring selection scale via `AnimatedContainer` wrapping chip
  - `HapticFeedback.lightImpact()` on selection
  - Color morph via `AnimatedContainer` on background

### 2.6 Error State Containers
- **File**: `lib/screens/summary_sheet.dart`
  - Error banner: spring entry (scale 0.9 → 1.0 + fade), icon with subtle shake animation
- **File**: `lib/screens/meeting_detail_screen.dart`
  - Failed content: expressive container with error icon + spring entry

### 2.7 Extended FAB with Spring Morph
- **File**: `lib/screens/meeting_library_screen.dart`
  - FAB: morphing between mic icon and "Recording" text label on long press
  - Uses `AnimatedContainer` with `StadiumBorder`, spring curve 500ms

---

## Phase 3: Dynamic Color + Polish

**Goal**: Material You support, reduced-motion accessibility, final polish.

### 3.1 Dynamic Color
- **File**: `pubspec.yaml`
  - Add: `dynamic_color: ^1.0.0`
- **File**: `lib/main.dart`
  - Wrap `MaterialApp` with `DynamicColorBuilder`
  - Use `dynamicLightScheme` / `dynamicDarkScheme` if available, fallback to seed color
  - Seed color fallback: deep indigo `Color(0xFF4F46E5)`

### 3.2 Reduced Motion
- Create utility: `lib/theme/reduced_motion.dart`
  - Extension on `BuildContext`: `bool get reduceMotion => MediaQuery.of(context).disableAnimations`
- Wrap all durations:
  ```dart
  Duration animDuration(BuildContext context, Duration base) =>
    context.reduceMotion ? Duration.zero : base;
  ```
- Apply to: all `AnimatedContainer`, `AnimatedBuilder`, `AnimationController`, `TweenAnimationBuilder`

### 3.3 Accessibility Final Pass
- Review all `Semantics` labels across: `_ActionButton`, `_FollowUpInput`, `_ChatBubble`, `_MetadataRow`, `_TranscribingIndicator`
- Touch target audit: ensure all buttons ≥ 48×48dp
- Verify contrast ratios on custom containers against `colorScheme` tokens

### 3.4 Final Polish
- **File**: `lib/screens/meeting_detail_screen.dart`
  - `DialogAction`: replace class with Dart 3 record `({String label, VoidCallback onPressed, bool isDefault})`
- **File**: `lib/theme/m3_tokens.dart`
  - Extract seed color to top-level constant for trivial future theming
- **File**: `lib/main.dart`
  - Add `useMaterial3: true` if not already (should be present)
  - Ensure all `Theme.of(context).textTheme` calls use themed styles
- Optimize remaining `const` constructor opportunities

---

## Excluded from Scope

- Architecture changes (providers, models, services)
- New feature functionality
- Test coverage (separate work stream)
- l10n setup (separate work stream)
- Backend/API changes

---

## File Impact Summary

| Phase | Files Touched | New Files |
|---|---|---|
| 1 | `main.dart`, `summary_sheet.dart`, `meeting_library_screen.dart`, `archived_meetings_screen.dart`, `meeting_detail_screen.dart`, `neumorphic_button.dart`, `meeting_share_sheet.dart`, `settings_screen.dart` | `lib/theme/m3_tokens.dart` |
| 2 | `meeting_library_screen.dart`, `meeting_detail_screen.dart`, `summary_sheet.dart` | `lib/widgets/spring_page_route.dart` |
| 3 | `main.dart`, `pubspec.yaml`, `m3_tokens.dart`, `reduced_motion.dart` | `lib/theme/reduced_motion.dart` |

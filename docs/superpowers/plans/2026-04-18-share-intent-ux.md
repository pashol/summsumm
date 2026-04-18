# Share Intent UX — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a PDF is shared into summsumm, show the library screen as a live background behind the summary sheet; pull down the sheet to reveal and interact with the library. Text shares keep the current behavior (pull down → close app).

**Architecture:** Add `scrollController` and `onClose` parameters to `SummarySheet` so it can be driven by an external `DraggableScrollableSheet` instead of its own internal one. A new `_DocumentSheetHost` widget renders `MeetingLibraryScreen` behind an external `DraggableScrollableSheet` containing `SummarySheet`; the library is blocked by `AbsorbPointer` while the sheet is up, and a `DraggableScrollableController` listener removes the sheet when it snaps to 0. Routing in `main.dart` is updated with a top-level `isDocumentShare` helper to select between the two host widgets.

**Tech Stack:** Flutter, Riverpod (Riverpod annotation / code-gen not needed for this change), `DraggableScrollableSheet`, `DraggableScrollableController`, `AbsorbPointer`, `AnimatedOpacity`

---

## File Map

| File | Change |
|---|---|
| `lib/screens/summary_sheet.dart` | Add `scrollController` + `onClose` params; extract `_buildBody` local fn; unify close logic |
| `lib/main.dart` | Add top-level `isDocumentShare()`; add `_DocumentSheetHost` widget; update home routing |
| `test/utils/document_share_test.dart` | New: unit tests for `isDocumentShare` |

---

## Task 1: Add `scrollController` and `onClose` to `SummarySheet`

**Files:**
- Modify: `lib/screens/summary_sheet.dart`

`SummarySheet` currently builds its own `DraggableScrollableSheet`. When `scrollController` is supplied (by an outer sheet), it must skip the inner one and render the body directly. When `onClose` is supplied it overrides the hardcoded `Navigator.of(context).pop()` in two places.

- [ ] **Step 1: Add the two new fields to the widget class**

In `lib/screens/summary_sheet.dart`, locate the `SummarySheet` class declaration (lines 18–33) and add two optional fields:

```dart
class SummarySheet extends ConsumerStatefulWidget {
  final List<Document> documents;
  final int initialIndex;
  final void Function(String summary)? onSummarized;
  final void Function(String error)? onSummaryFailed;
  final ScrollController? scrollController; // when set, skip inner DraggableScrollableSheet
  final VoidCallback? onClose;              // when set, overrides Navigator.pop()

  const SummarySheet({
    super.key,
    required this.documents,
    this.initialIndex = 0,
    this.onSummarized,
    this.onSummaryFailed,
    this.scrollController,
    this.onClose,
  });

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}
```

- [ ] **Step 2: Replace `build()` in `_SummarySheetState`**

Locate the `build` method (around line 212) and replace it entirely with the following. The key changes are: (a) a local `buildBody` function that takes a `ScrollController` so we avoid repeating the giant `_SheetBody` call, (b) `_handleClose` that respects `widget.onClose`, (c) conditional wrapping in `DraggableScrollableSheet`.

```dart
@override
Widget build(BuildContext context) {
  ref.listen<SummaryState>(summaryProvider, (prev, next) {
    if (prev?.status != SummaryStatus.done &&
        next.status == SummaryStatus.done) {
      widget.onSummarized?.call(next.summary);
    }
    if (prev?.status != SummaryStatus.error &&
        next.status == SummaryStatus.error) {
      widget.onSummaryFailed?.call(next.error ?? '');
    }
  });
  final summaryState = ref.watch(summaryProvider);
  final notifier = ref.read(summaryProvider.notifier);

  if (summaryState.status == SummaryStatus.error) {
    Future<void>.delayed(const Duration(seconds: 3)).then((_) {
      if (mounted) _handleClose(context);
    });
  }

  Widget buildBody(ScrollController scrollCtrl) => AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) => SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _SheetBody(
              scrollCtrl: scrollCtrl,
              sheetScrollCtrl: scrollCtrl,
              summaryState: summaryState,
              documents: widget.documents,
              activeIndex: _activeIndex,
              onIndexChanged: (i) => setState(() => _activeIndex = i),
              followUpCtrl: _followUpCtrl,
              followUpFocus: _followUpFocus,
              onCopy: () => _copyToClipboard(summaryState.summary),
              onReadAloud: () async {
                final settings = ref.read(settingsProvider);
                await notifier.startSpeaking(summaryState.summary, settings);
              },
              onPauseSpeaking: notifier.pauseSpeaking,
              onResumeSpeaking: notifier.resumeSpeaking,
              onStopSpeaking: notifier.stopSpeaking,
              onNewSummary: () async {
                await notifier.reset();
                await _startSummary();
              },
              onFactCheck: _factCheck,
              onClose: () => _handleClose(context),
              onSettings: _openSettings,
              onSendFollowUp: _sendFollowUp,
              isRecording: _isRecording,
              onLongPressStart: _startRecording,
              onLongPressEnd: _stopRecordingAndSendHandler,
              onRetryPdf: () async {
                final settings = ref.read(settingsProvider);
                final notifier = ref.read(settingsProvider.notifier);
                final apiKey =
                    await notifier.getApiKey(settings.provider) ?? '';
                await ref
                    .read(summaryProvider.notifier)
                    .retryPdfWithFallbackModel(
                      document: widget.documents[_activeIndex],
                      apiKey: apiKey,
                      settings: settings,
                    );
              },
            ),
          ),
        ),
      );

  if (widget.scrollController != null) return buildBody(widget.scrollController!);

  return DraggableScrollableSheet(
    initialChildSize: 0.8,
    minChildSize: 0.4,
    maxChildSize: 1.0,
    expand: false,
    builder: (_, sheetScrollCtrl) => buildBody(_scrollCtrl),
  );
}

void _handleClose(BuildContext context) {
  if (widget.onClose != null) {
    widget.onClose!();
  } else {
    Navigator.of(context).pop();
  }
}
```

- [ ] **Step 3: Run analyze**

```bash
flutter analyze lib/screens/summary_sheet.dart
```

Expected: no errors. If there are type errors on `_SheetBody` fields, check that `sheetScrollCtrl` accepts `ScrollController` (it does — it's typed `final ScrollController sheetScrollCtrl`).

- [ ] **Step 4: Run tests**

```bash
flutter test
```

Expected: all existing tests pass. No new tests are added yet for this change since `SummarySheet` requires the full widget tree to test.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/summary_sheet.dart
git commit -m "feat: add scrollController and onClose params to SummarySheet"
```

---

## Task 2: Add `isDocumentShare` helper and unit tests

**Files:**
- Modify: `lib/main.dart`
- Create: `test/utils/document_share_test.dart`

`isDocumentShare` is a top-level function (no underscore — needs to be importable in tests) that returns true when any document has a PDF URI. It lives in `main.dart` alongside the routing logic.

- [ ] **Step 1: Write the failing test**

Create `test/utils/document_share_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/main.dart';
import 'package:summsumm/models/document.dart';

void main() {
  group('isDocumentShare', () {
    test('returns false for empty list', () {
      expect(isDocumentShare([]), isFalse);
    });

    test('returns false when all documents are text-only', () {
      final docs = [
        Document(id: '1', text: 'hello world', uri: null),
        Document(id: '2', text: 'another text', uri: null),
      ];
      expect(isDocumentShare(docs), isFalse);
    });

    test('returns true when any document has a URI', () {
      final docs = [
        Document(id: '1', text: '', uri: 'content://com.example/file.pdf', name: 'file.pdf'),
      ];
      expect(isDocumentShare(docs), isTrue);
    });

    test('returns true for mixed text and pdf documents', () {
      final docs = [
        Document(id: '1', text: 'some text', uri: null),
        Document(id: '2', text: '', uri: 'content://com.example/doc.pdf', name: 'doc.pdf'),
      ];
      expect(isDocumentShare(docs), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/utils/document_share_test.dart
```

Expected: FAIL — `isDocumentShare` is not yet exported from `main.dart`.

- [ ] **Step 3: Add `isDocumentShare` to `main.dart`**

In `lib/main.dart`, add the following top-level function just before the `main()` function:

```dart
/// Returns true when any document is a PDF (has a content URI).
bool isDocumentShare(List<Document> documents) =>
    documents.any((d) => d.isPdf);
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/utils/document_share_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/utils/document_share_test.dart
git commit -m "feat: add isDocumentShare routing helper with tests"
```

---

## Task 3: Implement `_DocumentSheetHost`

**Files:**
- Modify: `lib/main.dart`

Add the new host widget below `_SummarySheetHost`. It renders `MeetingLibraryScreen` as the background, positions `SummarySheet` inside an external `DraggableScrollableSheet`, uses `AbsorbPointer` to block library interaction while the sheet is up, and a scrim that fades as the sheet is dragged down.

- [ ] **Step 1: Add `_DocumentSheetHost` and its state to `main.dart`**

Add the following two classes after the closing brace of `_SummarySheetHostState` in `lib/main.dart`:

```dart
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
                  ));
                },
                onSummaryFailed: (error) async {
                  await _repo.save(_entry.copyWith(
                    status: MeetingStatus.failed,
                    lastError: error,
                  ));
                },
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add missing import for `Colors` if needed**

`Colors` is part of `package:flutter/material.dart`, which is already imported. Verify no new imports are needed:

```bash
flutter analyze lib/main.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add _DocumentSheetHost with library background and draggable sheet"
```

---

## Task 4: Wire up routing and final verification

**Files:**
- Modify: `lib/main.dart`

Update the `home` selection in `SummsummApp.build()` to route PDF shares to `_DocumentSheetHost`.

- [ ] **Step 1: Update the `home` expression in `SummsummApp.build()`**

Locate this block in `_SummsummAppState.build()` (around line 140):

```dart
home: widget.openSettings
    ? const SettingsScreen(isInitialSetup: true)
    : widget.documents.isNotEmpty
        ? _SummarySheetHost(documents: widget.documents)
        : const MeetingLibraryScreen(),
```

Replace it with:

```dart
home: widget.openSettings
    ? const SettingsScreen(isInitialSetup: true)
    : isDocumentShare(widget.documents)
        ? _DocumentSheetHost(documents: widget.documents)
        : widget.documents.isNotEmpty
            ? _SummarySheetHost(documents: widget.documents)
            : const MeetingLibraryScreen(),
```

- [ ] **Step 2: Run analyze and all tests**

```bash
flutter analyze
flutter test
```

Expected: no errors, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: route PDF shares to _DocumentSheetHost with library background"
```

---

## Manual Verification Checklist

After building and running on a device (`flutter run`):

- [ ] Share a **PDF** from another app → library is visible behind the summary sheet; scrim dims the library; sheet is at ~92% height
- [ ] Drag the sheet halfway down on a PDF share → scrim fades, library becomes more visible; sheet snaps back to full height on release if above midpoint
- [ ] Drag the sheet fully down on a PDF share → sheet snaps to 0, library is fully visible and interactive; no `SystemNavigator.pop()`
- [ ] Tap the close (×) button on a PDF share → sheet animates down to 0, library is revealed
- [ ] Share **text** from another app → behavior unchanged: pulling down closes the app
- [ ] Open the app directly (no share intent) → `MeetingLibraryScreen` as before
- [ ] Share a PDF with no API key configured → sheet shows "No API key" snackbar, then dismisses to library (not the calling app)

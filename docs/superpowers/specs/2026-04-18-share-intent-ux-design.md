# Share Intent UX — Design Spec

**Date:** 2026-04-18

## Problem

When sharing a PDF into summsumm, the summary sheet opens over a black background
(the transparent `_SummarySheetHost` scaffold). The library exists but is invisible.
Additionally, text shares and document shares have different natural exit behaviors
that the current single-path architecture doesn't distinguish.

## Goals

- PDF share: library visible immediately behind the sheet; pull down reveals and activates library.
- Text share: pull down closes the app (existing behavior, unchanged).
- No regressions to the settings or direct-launch flows.

---

## Entry Routing (`main.dart`)

A helper `_isDocumentShare(List<Document> documents)` returns `true` when any
document has a non-null URI (i.e. is a PDF). Home widget selection:

| Condition | Home widget |
|---|---|
| `openSettings == true` | `SettingsScreen(isInitialSetup: true)` |
| document share | `_DocumentSheetHost(documents: ...)` |
| text share | `_SummarySheetHost(documents: ...)` ← unchanged |
| no intent | `MeetingLibraryScreen()` ← unchanged |

---

## `_DocumentSheetHost` (new widget)

Replaces the transparent-scaffold approach for PDF shares. Uses a `Stack` so the
library is always rendered and visible.

### Structure

```
Scaffold(
  body: Stack(
    children: [
      // layer 0 — library; blocked while sheet is up
      AbsorbPointer(
        absorbing: _sheetExtent > 0.2,
        child: MeetingLibraryScreen(),
      ),

      // layer 1 — scrim, opacity tracks sheet extent
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: _scrimOpacity,   // 0.54 * (extent / 0.92), clamped [0, 0.54]
          child: ColoredBox(color: Colors.black, child: SizedBox.expand()),
        ),
      ),

      // layer 2 — sheet (always receives pointer events for dragging)
      DraggableScrollableSheet(
        controller: _dragController,
        initialChildSize: 0.92,
        minChildSize: 0.0,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.0, 0.92],
        builder: (ctx, scrollCtrl) => SummarySheet(
          documents: widget.documents,
          scrollController: scrollCtrl,
          onSummarized: ...,
          onSummaryFailed: ...,
        ),
      ),
    ],
  ),
)
```

### Extent listener

In `initState`, attach a listener to `DraggableScrollableController`:

```dart
_dragController.addListener(() {
  final extent = _dragController.size;
  setState(() {
    _sheetExtent = extent;
    _scrimOpacity = (0.54 * (extent / 0.92)).clamp(0.0, 0.54);
  });
  if (extent == 0.0) {
    setState(() => _sheetVisible = false);
    // sheet removed from stack — library is now the full active screen
  }
});
```

`_sheetVisible` gates whether the sheet layers are included in the `Stack` at all.
Once false, the library is fully unobstructed and interactive. No `SystemNavigator.pop()`.

### Meeting repository save

Same as `_SummarySheetHost`: save a `Meeting` entry with `MeetingType.document`
before showing the sheet; update on `onSummarized` / `onSummaryFailed` callbacks.

---

## `SummarySheet` changes

Add an optional `scrollController` parameter:

```dart
final ScrollController? scrollController;
```

Pass it to the root scrollable widget inside `SummarySheet` (currently a
`SingleChildScrollView` or `ListView`). When null, the sheet creates its own
controller (preserving behavior when used as a modal bottom sheet from
`_SummarySheetHost` or `MeetingDetailScreen`).

---

## `_SummarySheetHost` (text share — unchanged)

No changes. Transparent scaffold, `showModalBottomSheet`, `SystemNavigator.pop()`
on dismiss.

---

## Out of scope

- Sharing multiple PDFs at once (carousel behavior already handled by `SummarySheet`).
- Any changes to the settings or direct-launch flows.
- Blur effect behind the sheet (plain scrim only).

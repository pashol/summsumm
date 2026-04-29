# Inline PDF Content Design

## Purpose

Imported PDFs currently show extracted text in the `Content` tab. Large PDFs can create huge text views, and extracted text loses layout and surrounding visual context. The `Content` tab should show the original PDF inline by default while keeping extracted text available for users who prefer it.

## Scope

This change applies to document meetings where the imported source file is a PDF. Existing and newly imported PDFs should use the same behavior because both store the original file path on `Meeting.audioPath` and extracted text on `Meeting.rawTranscript`.

Non-PDF document types remain extract-only if they are added later. Summary, chat, and RAG behavior continue to use extracted text and are not changed by this display preference.

## User Behavior

The `Content` tab for a PDF document displays the original PDF inline by default. The tab label remains `Content`.

Settings > Transcription gains a boolean preference named conceptually as “Show extracted PDF text only”. It defaults to off, so all PDFs open in the inline viewer unless the user enables the preference.

When the preference is enabled, PDF documents use the current extracted-text display in the `Content` tab. This gives users an explicit fallback for selectable text or devices where inline viewing is not desired.

## Architecture

Add `syncfusion_flutter_pdfviewer` as the PDF viewer dependency. The project already uses Syncfusion PDF tooling, so this keeps PDF functionality in one vendor family instead of introducing a separate stack.

`MeetingDetailScreen` owns the display decision for the `Content` tab:

```dart
if document is PDF and !settings.showExtractedPdfTextOnly:
  show inline PDF viewer from meeting.audioPath
else:
  show extracted text from meeting.transcript
```

The existing extracted-text widget should remain as a separate path rather than being removed. The PDF viewer path should use the saved file path directly, avoiding loading or rendering the full extracted text for large PDFs.

## Settings Persistence

Add a boolean field to `AppSettings`, defaulting to `false`, for the extracted-text-only preference. Persist it through the existing settings provider and SharedPreferences pattern. Existing serialized settings that do not contain the field must deserialize to `false`, preserving the new default inline PDF display.

Add localized strings for the settings row title and a short description explaining that this switches PDFs from the original inline document view to extracted text.

## Error Handling

If a PDF document has an empty path or the original PDF file is missing, the `Content` tab should show a localized unavailable-state message instead of silently falling back to extracted text. Silent fallback would hide the fact that the original document file is unavailable.

The extracted-text-only setting should still display extracted text when available, even if the original PDF file is missing, because that mode intentionally does not depend on the original file.

## Testing

Add or update tests to cover:

1. PDF document detail still labels the second tab as `Content`.
2. PDF documents default to the inline viewer path when the new setting is false or absent.
3. Enabling the extracted-text-only preference renders the stored extracted text.
4. Missing or empty PDF paths show a localized unavailable-state message in viewer mode.
5. `AppSettings` serialization and deserialization preserve the new field and default missing values to `false`.

## Out Of Scope

This design does not change PDF import, text extraction, summarization, chat, RAG indexing, or PDF export. It also does not add viewers for non-PDF document types.

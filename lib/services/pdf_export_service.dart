import 'dart:io';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/meeting.dart';
import '../models/transcription_config.dart';

class PdfExportService {
  // 2.2cm in points (1cm ≈ 28.3465 points)
  static const double _margin = 2.2 * 28.3465;
  static const double _fontSize = 11;
  static const double _titleFontSize = 14;
  static const double _footerFontSize = 9;

  static String _stripMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'#{1,6}\s'), (m) => '')
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'!\[.*?\]\(.*?\)'), (m) => '')
        .replaceAllMapped(RegExp(r'^\s*[-*]\s', multiLine: true), (m) => '• ')
        .replaceAllMapped(RegExp(r'^\s*\d+\.\s', multiLine: true), (m) => '')
        .replaceAllMapped(RegExp(r'\n{3,}'), (m) => '\n\n');
  }

  static Future<String> exportSummary(Meeting meeting) async {
    final summary = meeting.summary;
    if (summary == null || summary.isEmpty) {
      throw ArgumentError('Meeting has no summary to export');
    }
    return _exportPdf(
      title: meeting.title,
      date: meeting.createdAt,
      durationSec: meeting.durationSec,
      provider: meeting.provider,
      content: summary,
      type: 'Summary',
      speakerSegments: null,
    );
  }

  static Future<String> exportTranscript(Meeting meeting) async {
    final transcript = meeting.transcript;
    if (transcript == null || transcript.isEmpty) {
      throw ArgumentError('Meeting has no transcript to export');
    }
    return _exportPdf(
      title: meeting.title,
      date: meeting.createdAt,
      durationSec: meeting.durationSec,
      provider: meeting.provider,
      content: transcript,
      type: 'Transcript',
      speakerSegments: meeting.speakerSegments,
    );
  }

  static Future<String> _exportPdf({
    required String title,
    required DateTime date,
    required int durationSec,
    String? provider,
    required String content,
    required String type,
    List<SpeakerSegment>? speakerSegments,
  }) async {
    final document = PdfDocument();

    // A4 portrait with 2.2cm margins on all sides
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.orientation = PdfPageOrientation.portrait;
    document.pageSettings.margins.all = _margin;

    final page = document.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();

    var y = 0.0;

    // Title (14pt bold) — only on first page
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      _titleFontSize,
      style: PdfFontStyle.bold,
    );
    graphics.drawString(
      title,
      titleFont,
      bounds: Rect.fromLTWH(0, y, bounds.width, 30),
    );
    y += 30;

    // Metadata (11pt)
    final metaFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      _fontSize,
      style: PdfFontStyle.bold,
    );
    final metaValueFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      _fontSize,
    );
    final dateStr = DateFormat.yMMMd().add_Hm().format(date);
    final durationStr = _formatDuration(durationSec);

    y = _drawMetaRow(graphics, 'Date:', dateStr, 0, y, bounds.width, metaFont, metaValueFont);

    // Participants for transcripts (unique speakers, sorted)
    if (type == 'Transcript' && speakerSegments != null && speakerSegments.isNotEmpty) {
      final participants = speakerSegments
          .map((s) => s.speakerLabel)
          .toSet()
          .toList()
        ..sort();
      y = _drawMetaRow(
        graphics,
        'Participants:',
        participants.join(', '),
        0,
        y,
        bounds.width,
        metaFont,
        metaValueFont,
      );
    }

    y = _drawMetaRow(graphics, 'Duration:', durationStr, 0, y, bounds.width, metaFont, metaValueFont);
    if (provider != null) {
      y = _drawMetaRow(graphics, 'Provider:', provider, 0, y, bounds.width, metaFont, metaValueFont);
    }
    y += 8;

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(200, 200, 200)),
      Offset(0, y),
      Offset(bounds.width, y),
    );
    y += 12;

    // Content (11pt)
    final contentFont = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
    final contentBounds = Rect.fromLTWH(0, y, bounds.width, bounds.height - y);

    final String contentText;
    if (speakerSegments != null && speakerSegments.isNotEmpty) {
      // Each timestamp on its own line
      contentText = speakerSegments.map((segment) {
        final startMin = (segment.startTime ~/ 60).toString().padLeft(2, '0');
        final startSec = (segment.startTime % 60).toInt().toString().padLeft(2, '0');
        return '[$startMin:$startSec] ${segment.speakerLabel}: ${segment.text}';
      }).join('\n');
    } else {
      contentText = _stripMarkdown(content);
    }

    // Add page number footer
    _addPageNumberFooter(document);

    // Draw content — auto-flows across pages
    PdfTextElement(
      text: contentText,
      font: contentFont,
    ).draw(
      page: page,
      bounds: contentBounds,
    );

    final bytes = document.saveSync();
    document.dispose();

    final tempDir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = '${safeTitle}_$type.pdf';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  static void _addPageNumberFooter(PdfDocument document) {
    final footer = PdfPageTemplateElement(
      Rect.fromLTWH(
        0,
        0,
        document.pageSettings.size.width,
        30,
      ),
    );

    final font = PdfStandardFont(PdfFontFamily.helvetica, _footerFontSize);

    final pageNumber = PdfPageNumberField(font: font);
    final pageCount = PdfPageCountField(font: font);
    final composite = PdfCompositeField(
      font: font,
      text: 'Page {0} of {1}',
      fields: [pageNumber, pageCount],
    );

    composite.draw(
      footer.graphics,
      Offset(
        document.pageSettings.size.width / 2 - 30,
        5,
      ),
    );

    document.template.bottom = footer;
  }

  static double _drawMetaRow(
    PdfGraphics graphics,
    String label,
    String value,
    double x,
    double y,
    double width,
    PdfFont labelFont,
    PdfFont valueFont,
  ) {
    graphics.drawString(label, labelFont, bounds: Rect.fromLTWH(x, y, 70, 18));
    graphics.drawString(value, valueFont, bounds: Rect.fromLTWH(x + 72, y, width - 72, 18));
    return y + 18;
  }

  static String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

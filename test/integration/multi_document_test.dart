import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/models/document.dart';
import 'package:summsumm/widgets/document_carousel.dart';
import 'package:summsumm/screens/summary_sheet.dart';

void main() {
  group('Multi-Document Integration', () {
    testWidgets('Handles multiple documents', (tester) async {
      final documents = [
        Document(id: '1', text: 'Test document 1'),
        Document(id: '2', text: 'Test document 2'),
        Document(id: '3', text: 'Test document 3'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SummarySheet(documents: documents),
          ),
        ),
      );

      // Wait for the sheet to build
      await tester.pumpAndSettle();

      // Verify DocumentCarousel is present
      expect(find.byType(DocumentCarousel), findsOneWidget);

      // Verify all document chips are present
      expect(find.text('Doc 1'), findsOneWidget);
      expect(find.text('Doc 2'), findsOneWidget);
      expect(find.text('Doc 3'), findsOneWidget);
    });

    testWidgets('Switches active document on tap', (tester) async {
      final documents = [
        Document(id: '1', text: 'First document'),
        Document(id: '2', text: 'Second document'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SummarySheet(documents: documents),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on second document
      await tester.tap(find.text('Doc 2'));
      await tester.pumpAndSettle();

      // Verify the second document is now active (has different styling)
      expect(find.text('Doc 2'), findsOneWidget);
    });

    testWidgets('Displays text preview', (tester) async {
      final documents = [
        Document(id: '1', text: 'This is a test document for preview'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SummarySheet(documents: documents),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text preview is shown
      expect(find.text(documents[0].text), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:summsumm/l10n/app_localizations.dart';
import '../models/document.dart';

class DocumentCarousel extends ConsumerWidget {
  final List<Document> documents;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;

  const DocumentCarousel({
    super.key,
    required this.documents,
    required this.activeIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;
          return GestureDetector(
            onTap: () => onIndexChanged(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Center(
                child: Text(
                  documents[index].title ?? AppLocalizations.of(context)!.carouselDocFallback(index + 1),
                  style: TextStyle(
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

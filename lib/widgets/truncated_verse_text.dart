import 'package:flutter/material.dart';

/// Truncates text to fit on a single line. If the text does not fit within
/// [maxWidth], it cuts off at the maximum character position that accommodates
/// the characters plus the trailing ellipsis `...`.
///
/// This does not drop the entire trailing word; instead, it fills the available
/// line width with whatever letters fit (reserving spots for `...`), adhering
/// strictly to single-line display.
String truncateVerseToOneLine(String text, TextStyle style, double maxWidth) {
  if (maxWidth <= 0 || text.isEmpty) return text;
  final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleanText.isEmpty) return '';

  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );

  // If the entire text fits on one line, return it as-is without dots
  textPainter.text = TextSpan(text: cleanText, style: style);
  textPainter.layout(maxWidth: double.infinity);
  if (textPainter.width <= maxWidth) {
    return cleanText;
  }

  const ellipsis = '...';
  int low = 1;
  int high = cleanText.length;
  int bestIndex = 0;

  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final candidate = '${cleanText.substring(0, mid)}$ellipsis';
    textPainter.text = TextSpan(text: candidate, style: style);
    textPainter.layout(maxWidth: double.infinity);

    if (textPainter.width <= maxWidth) {
      bestIndex = mid;
      low = mid + 1; // Try to fit more characters
    } else {
      high = mid - 1; // Exceeded width, step back
    }
  }

  if (bestIndex > 0) {
    final truncatedSub = cleanText.substring(0, bestIndex);
    return '${truncatedSub.trimRight()}$ellipsis';
  } else {
    return ellipsis;
  }
}

class TruncatedVerseText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const TruncatedVerseText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (availableWidth <= 0 || availableWidth.isInfinite) {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final truncated = truncateVerseToOneLine(text, style, availableWidth);
        return Text(
          truncated,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

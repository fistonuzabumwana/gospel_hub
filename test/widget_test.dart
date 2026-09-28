import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gospel_hub/models/bible_book.dart';
import 'package:gospel_hub/widgets/truncated_verse_text.dart';

void main() {
  test('BibleBook getDisplayName translation mode test', () {
    final book = BibleBook.allBooks[0]; // Genesis
    
    // In English translation mode, it should return English name
    expect(book.getDisplayName('english'), 'Genesis');
    
    // In Parallel or Kinyarwanda translation mode, it should return Kinyarwanda name
    expect(book.getDisplayName('parallel'), 'Intangiriro');
    expect(book.getDisplayName('kinyarwanda'), 'Intangiriro');
  });

  test('truncateVerseToOneLine returns exact text when it fits within maxWidth', () {
    const text = 'Yesu ararira.';
    const style = TextStyle(fontSize: 14);
    final result = truncateVerseToOneLine(text, style, 500);
    expect(result, 'Yesu ararira.');
    expect(result.endsWith('...'), isFalse);
  });

  test('truncateVerseToOneLine truncates with dots when text exceeds maxWidth', () {
    const text = 'Mu ntangiriro Jambo yariho, kandi Jambo yahoranye n\'Imana, kandi Jambo yari Imana.';
    const style = TextStyle(fontSize: 14);
    final result = truncateVerseToOneLine(text, style, 150);
    expect(result.endsWith('...'), isTrue);
    expect(result.length < text.length, isTrue);

    // Verify candidate with ellipsis fits within maxWidth
    final painter = TextPainter(
      text: TextSpan(text: result, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    expect(painter.width <= 150, isTrue);
  });
}


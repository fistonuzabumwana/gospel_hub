import 'package:flutter_test/flutter_test.dart';
import 'package:gospel_hub/models/bible_book.dart';

void main() {
  test('BibleBook getDisplayName translation mode test', () {
    final book = BibleBook.allBooks[0]; // Genesis
    
    // In English translation mode, it should return English name
    expect(book.getDisplayName('english'), 'Genesis');
    
    // In Parallel or Kinyarwanda translation mode, it should return Kinyarwanda name
    expect(book.getDisplayName('parallel'), 'Intangiriro');
    expect(book.getDisplayName('kinyarwanda'), 'Intangiriro');
  });
}

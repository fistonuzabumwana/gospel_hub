import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/bible_book.dart';

class WidgetVerseRef {
  final int bookNumber;
  final int chapter;
  final int verse;

  const WidgetVerseRef(this.bookNumber, this.chapter, this.verse);
}

class WidgetService {
  static const _channel = MethodChannel('com.gospelhub.app/widget');

  static const List<WidgetVerseRef> _widgetVerseRefs = [
    WidgetVerseRef(43, 3, 16), // Yohana / John 3:16
    WidgetVerseRef(6, 1, 9),   // Yosuwa / Joshua 1:9
    WidgetVerseRef(19, 23, 1), // Zaburi / Psalms 23:1
    WidgetVerseRef(45, 8, 28), // Abaroma / Romans 8:28
    WidgetVerseRef(20, 3, 5),  // Imigani / Proverbs 3:5
    WidgetVerseRef(50, 4, 13), // Abafilipi / Philippians 4:13
  ];

  static Future<void> syncWidgetData(String currentLanguage) async {
    try {
      final db = DatabaseService();
      final prefs = await SharedPreferences.getInstance();

      // Write active language
      await prefs.setString('widget_language', currentLanguage);

      // Write count of verses
      await prefs.setInt('widget_verses_count', _widgetVerseRefs.length);

      // If active index is not set, initialize it to the day of month index
      if (!prefs.containsKey('widget_verse_index')) {
        final dayIndex = DateTime.now().day % _widgetVerseRefs.length;
        await prefs.setInt('widget_verse_index', dayIndex);
      }

      // Fetch and save each verse in both languages
      for (int i = 0; i < _widgetVerseRefs.length; i++) {
        final ref = _widgetVerseRefs[i];
        final book = BibleBook.allBooks.firstWhere(
          (b) => b.bookNumber == ref.bookNumber,
          orElse: () => BibleBook.allBooks.first,
        );

        // Fetch English text
        final textEn = await db.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, true);
        final bookNameEn = book.getDisplayName('english');
        await prefs.setString('widget_verse_ref_en_$i', '$bookNameEn ${ref.chapter}:${ref.verse}');
        await prefs.setString('widget_verse_text_en_$i', textEn ?? '');

        // Fetch Kinyarwanda text
        final textRw = await db.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, false);
        final bookNameRw = book.getDisplayName('kinyarwanda');
        await prefs.setString('widget_verse_ref_rw_$i', '$bookNameRw ${ref.chapter}:${ref.verse}');
        await prefs.setString('widget_verse_text_rw_$i', textRw ?? '');
      }

      // Notify native Android side to refresh RemoteViews
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Quietly log error in debug
      print('Error syncing widget data: $e');
    }
  }
}

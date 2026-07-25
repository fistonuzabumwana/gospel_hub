/// Shared verse pool and "verse of the day" index used by the home dashboard and widget.
class DailyVerseRef {
  final int bookNumber;
  final int chapter;
  final int verse;

  const DailyVerseRef(this.bookNumber, this.chapter, this.verse);
}

class DailyVerseService {
  static const List<DailyVerseRef> verseRefs = [
    DailyVerseRef(43, 3, 16), // Yohana / John 3:16
    DailyVerseRef(6, 1, 9), // Yosuwa / Joshua 1:9
    DailyVerseRef(19, 23, 1), // Zaburi / Psalms 23:1
    DailyVerseRef(45, 8, 28), // Abaroma / Romans 8:28
    DailyVerseRef(20, 3, 5), // Imigani / Proverbs 3:5
    DailyVerseRef(50, 4, 13), // Abafilipi / Philippians 4:13
  ];

  static int get verseCount => verseRefs.length;

  /// Same algorithm as the home screen "Verse of the Day" card.
  static int todayVerseIndex([DateTime? date]) {
    final d = date ?? DateTime.now();
    return d.day % verseRefs.length;
  }

  static DailyVerseRef todayVerseRef([DateTime? date]) {
    return verseRefs[todayVerseIndex(date)];
  }

  static String dayKeyFor(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

/// Shared verse pool and "verse of the day" index used by the home dashboard and widget.
class DailyVerseRef {
  final int bookNumber;
  final int chapter;
  final int verse;

  const DailyVerseRef(this.bookNumber, this.chapter, this.verse);
}

class DailyVerseService {
  // Verified 31 inspirational daily verses mapped to exact BibleBook.allBooks indices (73-book canon)
  static const List<DailyVerseRef> verseRefs = [
    DailyVerseRef(50, 3, 16),  // 1: Yohana / John 3:16
    DailyVerseRef(6, 1, 9),    // 2: Yosuwa / Joshua 1:9
    DailyVerseRef(23, 23, 1),  // 3: Zaburi / Psalms 23:1
    DailyVerseRef(52, 8, 28),  // 4: Abaroma / Romans 8:28
    DailyVerseRef(24, 3, 5),   // 5: Imigani / Proverbs 3:5
    DailyVerseRef(57, 4, 13),  // 6: Abafilipi / Philippians 4:13
    DailyVerseRef(30, 29, 11), // 7: Yeremiya / Jeremiah 29:11
    DailyVerseRef(29, 40, 31), // 8: Yesaya / Isaiah 40:31
    DailyVerseRef(47, 6, 33),  // 9: Matayo / Matthew 6:33
    DailyVerseRef(47, 11, 28), // 10: Matayo / Matthew 11:28
    DailyVerseRef(54, 5, 17),  // 11: 2 Abakorinto / 2 Corinthians 5:17
    DailyVerseRef(55, 5, 22),  // 12: Abagalatiya / Galatians 5:22
    DailyVerseRef(56, 2, 8),   // 13: Abefeso / Ephesians 2:8
    DailyVerseRef(67, 5, 7),   // 14: 1 Petero / 1 Peter 5:7
    DailyVerseRef(65, 11, 1),  // 15: Abaheburayo / Hebrews 11:1
    DailyVerseRef(23, 119, 105), // 16: Zaburi / Psalms 119:105
    DailyVerseRef(23, 46, 1),  // 17: Zaburi / Psalms 46:1
    DailyVerseRef(24, 16, 3),  // 18: Imigani / Proverbs 16:3
    DailyVerseRef(29, 41, 10), // 19: Yesaya / Isaiah 41:10
    DailyVerseRef(52, 12, 2),  // 20: Abaroma / Romans 12:2
    DailyVerseRef(53, 13, 13), // 21: 1 Abakorinto / 1 Corinthians 13:13
    DailyVerseRef(62, 1, 7),   // 22: 2 Timoteyo / 2 Timothy 1:7
    DailyVerseRef(23, 27, 1),  // 23: Zaburi / Psalms 27:1
    DailyVerseRef(23, 34, 8),  // 24: Zaburi / Psalms 34:8
    DailyVerseRef(50, 14, 6),  // 25: Yohana / John 14:6
    DailyVerseRef(50, 8, 12),  // 26: Yohana / John 8:12
    DailyVerseRef(58, 3, 23),  // 27: Abakolosayi / Colossians 3:23
    DailyVerseRef(66, 1, 5),   // 28: Yakobo / James 1:5
    DailyVerseRef(69, 4, 19),  // 29: 1 Yohana / 1 John 4:19
    DailyVerseRef(73, 21, 4),  // 30: Ibyahishuwe / Revelation 21:4
    DailyVerseRef(1, 1, 1),    // 31: Intangiriro / Genesis 1:1
  ];

  static int get verseCount => verseRefs.length;

  /// Returns a pseudo-random, non-repeating verse index for any given date.
  /// Uses a monthly seeded permutation so verses feel randomized,
  /// but no verse is repeated within the same month.
  static int todayVerseIndex([DateTime? date]) {
    final d = date ?? DateTime.now();
    final dayInMonth = d.day.clamp(1, 31);
    final monthKey = d.year * 12 + d.month;

    // Fast 32-bit hash seed for the current month
    int hash = (monthKey ^ 0x5DEECE66D) * 0x27D4EB2D;
    hash = (hash ^ (hash >> 15)) * 0x85EBCA6B;
    final int seed = hash.abs() % verseRefs.length;

    // Linear Congruential Permutation: (17 * (day - 1) + seed) % 31
    // Since 17 and 31 are coprime primes, this generates a 100% unique, 
    // non-repeating pseudo-random permutation of all 31 verses per month.
    return (17 * (dayInMonth - 1) + seed) % verseRefs.length;
  }

  static DailyVerseRef todayVerseRef([DateTime? date]) {
    return verseRefs[todayVerseIndex(date)];
  }

  static String dayKeyFor(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

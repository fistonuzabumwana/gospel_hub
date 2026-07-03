class BibleBook {
  final int bookNumber;
  final String name;
  final String englishName;
  final String testament;
  final int chapterCount;

  const BibleBook({
    required this.bookNumber,
    required this.name,
    required this.englishName,
    required this.testament,
    required this.chapterCount,
  });

  bool get isOldTestament => testament == 'Old';

  static const List<BibleBook> allBooks = [
    // Old Testament (39 books)
    BibleBook(bookNumber: 1, name: "Intangiriro", englishName: "Genesis", testament: "Old", chapterCount: 50),
    BibleBook(bookNumber: 2, name: "Kuva", englishName: "Exodus", testament: "Old", chapterCount: 40),
    BibleBook(bookNumber: 3, name: "Abalewi", englishName: "Leviticus", testament: "Old", chapterCount: 27),
    BibleBook(bookNumber: 4, name: "Kubara", englishName: "Numbers", testament: "Old", chapterCount: 36),
    BibleBook(bookNumber: 5, name: "Gutegeka kwa Kabiri", englishName: "Deuteronomy", testament: "Old", chapterCount: 34),
    BibleBook(bookNumber: 6, name: "Yosuwa", englishName: "Joshua", testament: "Old", chapterCount: 24),
    BibleBook(bookNumber: 7, name: "Abacamanza", englishName: "Judges", testament: "Old", chapterCount: 21),
    BibleBook(bookNumber: 8, name: "Rusi", englishName: "Ruth", testament: "Old", chapterCount: 4),
    BibleBook(bookNumber: 9, name: "1 Samweli", englishName: "1 Samuel", testament: "Old", chapterCount: 31),
    BibleBook(bookNumber: 10, name: "2 Samweli", englishName: "2 Samuel", testament: "Old", chapterCount: 24),
    BibleBook(bookNumber: 11, name: "1 Abami", englishName: "1 Kings", testament: "Old", chapterCount: 22),
    BibleBook(bookNumber: 12, name: "2 Abami", englishName: "2 Kings", testament: "Old", chapterCount: 25),
    BibleBook(bookNumber: 13, name: "1 Ibyo ku Ngoma", englishName: "1 Chronicles", testament: "Old", chapterCount: 29),
    BibleBook(bookNumber: 14, name: "2 Ibyo ku Ngoma", englishName: "2 Chronicles", testament: "Old", chapterCount: 36),
    BibleBook(bookNumber: 15, name: "Ezira", englishName: "Ezra", testament: "Old", chapterCount: 10),
    BibleBook(bookNumber: 16, name: "Nehemiya", englishName: "Nehemiah", testament: "Old", chapterCount: 13),
    BibleBook(bookNumber: 17, name: "Esiteri", englishName: "Esther", testament: "Old", chapterCount: 10),
    BibleBook(bookNumber: 18, name: "Yobu", englishName: "Job", testament: "Old", chapterCount: 42),
    BibleBook(bookNumber: 19, name: "Zaburi", englishName: "Psalms", testament: "Old", chapterCount: 150),
    BibleBook(bookNumber: 20, name: "Imigani", englishName: "Proverbs", testament: "Old", chapterCount: 31),
    BibleBook(bookNumber: 21, name: "Umubwiriza", englishName: "Ecclesiastes", testament: "Old", chapterCount: 12),
    BibleBook(bookNumber: 22, name: "Indirimbo ya Salomo", englishName: "Song of Solomon", testament: "Old", chapterCount: 8),
    BibleBook(bookNumber: 23, name: "Yesaya", englishName: "Isaiah", testament: "Old", chapterCount: 66),
    BibleBook(bookNumber: 24, name: "Yeremiya", englishName: "Jeremiah", testament: "Old", chapterCount: 52),
    BibleBook(bookNumber: 25, name: "Amaganya", englishName: "Lamentations", testament: "Old", chapterCount: 5),
    BibleBook(bookNumber: 26, name: "Ezekiyeli", englishName: "Ezekiel", testament: "Old", chapterCount: 48),
    BibleBook(bookNumber: 27, name: "Daniyeli", englishName: "Daniel", testament: "Old", chapterCount: 12),
    BibleBook(bookNumber: 28, name: "Hoseya", englishName: "Hosea", testament: "Old", chapterCount: 14),
    BibleBook(bookNumber: 29, name: "Yoweli", englishName: "Joel", testament: "Old", chapterCount: 3),
    BibleBook(bookNumber: 30, name: "Amosi", englishName: "Amos", testament: "Old", chapterCount: 9),
    BibleBook(bookNumber: 31, name: "Obadiya", englishName: "Obadiah", testament: "Old", chapterCount: 1),
    BibleBook(bookNumber: 32, name: "Yona", englishName: "Jonah", testament: "Old", chapterCount: 4),
    BibleBook(bookNumber: 33, name: "Mika", englishName: "Micah", testament: "Old", chapterCount: 7),
    BibleBook(bookNumber: 34, name: "Nahumu", englishName: "Nahum", testament: "Old", chapterCount: 3),
    BibleBook(bookNumber: 35, name: "Habakuki", englishName: "Habakkuk", testament: "Old", chapterCount: 3),
    BibleBook(bookNumber: 36, name: "Zefaniya", englishName: "Zephaniah", testament: "Old", chapterCount: 3),
    BibleBook(bookNumber: 37, name: "Hagayi", englishName: "Haggai", testament: "Old", chapterCount: 2),
    BibleBook(bookNumber: 38, name: "Zekariya", englishName: "Zechariah", testament: "Old", chapterCount: 14),
    BibleBook(bookNumber: 39, name: "Malaki", englishName: "Malachi", testament: "Old", chapterCount: 4),

    // New Testament (27 books)
    BibleBook(bookNumber: 40, name: "Matayo", englishName: "Matthew", testament: "New", chapterCount: 28),
    BibleBook(bookNumber: 41, name: "Mariko", englishName: "Mark", testament: "New", chapterCount: 16),
    BibleBook(bookNumber: 42, name: "Luka", englishName: "Luke", testament: "New", chapterCount: 24),
    BibleBook(bookNumber: 43, name: "Yohana", englishName: "John", testament: "New", chapterCount: 21),
    BibleBook(bookNumber: 44, name: "Ibyakozwe n'Intumwa", englishName: "Acts", testament: "New", chapterCount: 28),
    BibleBook(bookNumber: 45, name: "Abaroma", englishName: "Romans", testament: "New", chapterCount: 16),
    BibleBook(bookNumber: 46, name: "1 Abakorinto", englishName: "1 Corinthians", testament: "New", chapterCount: 16),
    BibleBook(bookNumber: 47, name: "2 Abakorinto", englishName: "2 Corinthians", testament: "New", chapterCount: 13),
    BibleBook(bookNumber: 48, name: "Abagalatiya", englishName: "Galatians", testament: "New", chapterCount: 6),
    BibleBook(bookNumber: 49, name: "Abefeso", englishName: "Ephesians", testament: "New", chapterCount: 6),
    BibleBook(bookNumber: 50, name: "Abfilipi", englishName: "Philippians", testament: "New", chapterCount: 4),
    BibleBook(bookNumber: 51, name: "Abakolosayi", englishName: "Colossians", testament: "New", chapterCount: 4),
    BibleBook(bookNumber: 52, name: "1 Abatesalonike", englishName: "1 Thessalonians", testament: "New", chapterCount: 5),
    BibleBook(bookNumber: 53, name: "2 Abatesalonike", englishName: "2 Thessalonians", testament: "New", chapterCount: 3),
    BibleBook(bookNumber: 54, name: "1 Timoteyo", englishName: "1 Timothy", testament: "New", chapterCount: 6),
    BibleBook(bookNumber: 55, name: "2 Timoteyo", englishName: "2 Timothy", testament: "New", chapterCount: 4),
    BibleBook(bookNumber: 56, name: "Tito", englishName: "Titus", testament: "New", chapterCount: 3),
    BibleBook(bookNumber: 57, name: "Filemoni", englishName: "Philemon", testament: "New", chapterCount: 1),
    BibleBook(bookNumber: 58, name: "Abaheburayo", englishName: "Hebrews", testament: "New", chapterCount: 13),
    BibleBook(bookNumber: 59, name: "Yakobo", englishName: "James", testament: "New", chapterCount: 5),
    BibleBook(bookNumber: 60, name: "1 Petero", englishName: "1 Peter", testament: "New", chapterCount: 5),
    BibleBook(bookNumber: 61, name: "2 Petero", englishName: "2 Peter", testament: "New", chapterCount: 3),
    BibleBook(bookNumber: 62, name: "1 Yohana", englishName: "1 John", testament: "New", chapterCount: 5),
    BibleBook(bookNumber: 63, name: "2 Yohana", englishName: "2 John", testament: "New", chapterCount: 1),
    BibleBook(bookNumber: 64, name: "3 Yohana", englishName: "3 John", testament: "New", chapterCount: 1),
    BibleBook(bookNumber: 65, name: "Yuda", englishName: "Jude", testament: "New", chapterCount: 1),
    BibleBook(bookNumber: 66, name: "Ibyahishuwe", englishName: "Revelation", testament: "New", chapterCount: 22),
  ];

  static BibleBook getByNumber(int number) {
    return allBooks.firstWhere((b) => b.bookNumber == number, 
      orElse: () => allBooks.first
    );
  }
}
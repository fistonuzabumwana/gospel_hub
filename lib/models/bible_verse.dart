class BibleVerse {
  final int? id;
  final int versionId;
  final int bookId;
  final int chapterNumber;
  final int verseNumber;
  final String verseText;

  BibleVerse({
    this.id,
    required this.versionId,
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    required this.verseText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version_id': versionId,
      'book_id': bookId,
      'chapter_number': chapterNumber,
      'verse_number': verseNumber,
      'verse_text': verseText,
    };
  }

  factory BibleVerse.fromMap(Map<String, dynamic> map) {
    return BibleVerse(
      id: map['id'],
      versionId: map['version_id'],
      bookId: map['book_id'],
      chapterNumber: map['chapter_number'],
      verseNumber: map['verse_number'],
      verseText: map['verse_text'],
    );
  }
}
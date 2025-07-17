class BibleBook {
  final int? id;
  final int bookNumber;
  final String bookNameEn;
  final String bookNameKinyarwanda;
  final String bookNameFrench;
  final String testament;
  final int chapterCount;

  BibleBook({
    this.id,
    required this.bookNumber,
    required this.bookNameEn,
    required this.bookNameKinyarwanda,
    required this.bookNameFrench,
    required this.testament,
    required this.chapterCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_number': bookNumber,
      'book_name_en': bookNameEn,
      'book_name_kinyarwanda': bookNameKinyarwanda,
      'book_name_french': bookNameFrench,
      'testament': testament,
      'chapter_count': chapterCount,
    };
  }

  factory BibleBook.fromMap(Map<String, dynamic> map) {
    return BibleBook(
      id: map['id'],
      bookNumber: map['book_number'],
      bookNameEn: map['book_name_en'],
      bookNameKinyarwanda: map['book_name_kinyarwanda'],
      bookNameFrench: map['book_name_french'],
      testament: map['testament'],
      chapterCount: map['chapter_count'],
    );
  }
}
class BibleVerse {
  final int? id;
  final int book;
  final int chapter;
  final int verse;
  final String text;
  final String testament;
  final String? heading;

  BibleVerse({
    this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.testament,
    this.heading,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'testament': testament,
      'heading': heading,
    };
  }

  factory BibleVerse.fromMap(Map<String, dynamic> map) {
    return BibleVerse(
      id: map['id'] as int?,
      book: map['book'] as int? ?? 1,
      chapter: map['chapter'] as int? ?? 1,
      verse: map['verse'] as int? ?? 1,
      text: map['text'] as String? ?? '',
      testament: map['testament'] as String? ?? 'Old',
      heading: map['heading'] as String?,
    );
  }
}
class Hymn {
  final int? id;
  final int hymnNumber;
  final String titleEn;
  final String titleKinyarwanda;
  final String titleFrench;
  final int categoryId;
  final String lyricsEn;
  final String lyricsKinyarwanda;
  final String lyricsFrench;
  final String firstLine;

  Hymn({
    this.id,
    required this.hymnNumber,
    required this.titleEn,
    required this.titleKinyarwanda,
    required this.titleFrench,
    required this.categoryId,
    required this.lyricsEn,
    required this.lyricsKinyarwanda,
    required this.lyricsFrench,
    required this.firstLine,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hymn_number': hymnNumber,
      'title_en': titleEn,
      'title_kinyarwanda': titleKinyarwanda,
      'title_french': titleFrench,
      'category_id': categoryId,
      'lyrics_en': lyricsEn,
      'lyrics_kinyarwanda': lyricsKinyarwanda,
      'lyrics_french': lyricsFrench,
      'first_line': firstLine,
    };
  }

  factory Hymn.fromMap(Map<String, dynamic> map) {
    return Hymn(
      id: map['id'],
      hymnNumber: map['hymn_number'],
      titleEn: map['title_en'],
      titleKinyarwanda: map['title_kinyarwanda'],
      titleFrench: map['title_french'],
      categoryId: map['category_id'],
      lyricsEn: map['lyrics_en'],
      lyricsKinyarwanda: map['lyrics_kinyarwanda'],
      lyricsFrench: map['lyrics_french'],
      firstLine: map['first_line'],
    );
  }
}
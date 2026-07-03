import 'dart:convert';

class Hymn {
  final int? id;
  final String book;      // 'Gushimisha' or 'Agakiza'
  final int number;
  final String title;
  final String slug;
  final String uuid;
  final String category;
  final List<LyricsBlock> lyrics;

  Hymn({
    this.id,
    required this.book,
    required this.number,
    required this.title,
    required this.slug,
    required this.uuid,
    required this.category,
    required this.lyrics,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book': book,
      'number': number,
      'title': title,
      'slug': slug,
      'uuid': uuid,
      'category': category,
      'lyrics': json.encode(lyrics.map((l) => l.toMap()).toList()),
    };
  }

  factory Hymn.fromMap(Map<String, dynamic> map) {
    List<dynamic> lyricsJson = [];
    try {
      if (map['lyrics'] != null) {
        lyricsJson = json.decode(map['lyrics'] as String) as List<dynamic>;
      }
    } catch (e) {
      print('Error parsing lyrics JSON: $e');
    }

    return Hymn(
      id: map['id'] as int?,
      book: map['book'] as String? ?? 'Gushimisha',
      number: map['number'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      uuid: map['uuid'] as String? ?? '',
      category: map['category'] as String? ?? '',
      lyrics: lyricsJson.map((l) => LyricsBlock.fromMap(l as Map<String, dynamic>)).toList(),
    );
  }
}

class LyricsBlock {
  final String type;      // 'verse' or 'chorus'
  final int? number;      // Verse number, null if chorus
  final List<String> lines;

  LyricsBlock({
    required this.type,
    this.number,
    required this.lines,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (number != null) 'number': number,
      'lines': lines,
    };
  }

  factory LyricsBlock.fromMap(Map<String, dynamic> map) {
    return LyricsBlock(
      type: map['type'] as String? ?? 'verse',
      number: map['number'] as int?,
      lines: List<String>.from(map['lines'] ?? []),
    );
  }
}
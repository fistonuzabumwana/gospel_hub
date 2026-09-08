import 'dart:convert';

class Hymn {
  final int? id;
  final String book;      // 'Gushimisha' or 'Agakiza'
  final int number;
  final String title;
  final String slug;
  final String uuid;
  final String category;
  final String rawLyrics;
  List<LyricsBlock>? _parsedLyrics;

  Hymn({
    this.id,
    required this.book,
    required this.number,
    required this.title,
    required this.slug,
    required this.uuid,
    required this.category,
    String? rawLyrics,
    List<LyricsBlock>? lyrics,
  })  : rawLyrics = rawLyrics ?? '',
        _parsedLyrics = lyrics;

  List<LyricsBlock> get lyrics {
    if (_parsedLyrics != null) return _parsedLyrics!;
    if (rawLyrics.isEmpty) {
      _parsedLyrics = [];
      return _parsedLyrics!;
    }
    try {
      final List<dynamic> lyricsJson = json.decode(rawLyrics) as List<dynamic>;
      _parsedLyrics = lyricsJson
          .map((l) => LyricsBlock.fromMap(l as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing lyrics JSON: $e');
      _parsedLyrics = [];
    }
    return _parsedLyrics!;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book': book,
      'number': number,
      'title': title,
      'slug': slug,
      'uuid': uuid,
      'category': category,
      'lyrics': rawLyrics.isNotEmpty ? rawLyrics : json.encode(lyrics.map((l) => l.toMap()).toList()),
    };
  }

  factory Hymn.fromMap(Map<String, dynamic> map) {
    final raw = map['lyrics'];
    String rawLyricsStr = '';
    List<LyricsBlock>? parsed;

    if (raw is String) {
      rawLyricsStr = raw;
    } else if (raw is List) {
      try {
        parsed = raw.map((l) => LyricsBlock.fromMap(l as Map<String, dynamic>)).toList();
        rawLyricsStr = json.encode(raw);
      } catch (_) {}
    }

    return Hymn(
      id: map['id'] as int?,
      book: map['book'] as String? ?? 'Gushimisha',
      number: map['number'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      uuid: map['uuid'] as String? ?? '',
      category: map['category'] as String? ?? '',
      rawLyrics: rawLyricsStr,
      lyrics: parsed,
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
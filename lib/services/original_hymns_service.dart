import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/original_hymn.dart';
import '../models/hymn.dart';
import 'database_service.dart';

class OriginalHymnsService {
  static final OriginalHymnsService _instance = OriginalHymnsService._internal();
  factory OriginalHymnsService() => _instance;
  OriginalHymnsService._internal();

  final Map<int, List<OriginalHymn>> _hymnsByNumber = {};
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;

  Future<void> ensureLoaded() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      final dbService = DatabaseService();
      final rows = await dbService.getAllOriginalHymnsRaw();

      _hymnsByNumber.clear();

      for (final row in rows) {
        final hymnNumber = row['hymn_number'] as int?;
        if (hymnNumber == null) continue;

        final lyricsRaw = row['lyrics'];
        List<LyricsBlock> parsedLyrics = [];
        if (lyricsRaw is String && lyricsRaw.isNotEmpty) {
          try {
            final decoded = json.decode(lyricsRaw);
            if (decoded is List) {
              parsedLyrics = decoded
                  .whereType<Map>()
                  .map((b) => LyricsBlock.fromMap(Map<String, dynamic>.from(b)))
                  .toList();
            }
          } catch (_) {}
        }

        final originalHymn = OriginalHymn(
          songNumber: hymnNumber.toString(),
          originalSearchName: row['original_search_name'] as String? ?? '',
          language: row['language'] as String? ?? '',
          title: row['title'] as String? ?? '',
          lyrics: parsedLyrics,
          audioFile: row['audio_file'] as String?,
          midiFile: row['midi_file'] as String?,
        );

        _hymnsByNumber.putIfAbsent(hymnNumber, () => []).add(originalHymn);
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading original hymns from SQLite: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Returns the original hymns (English/French) for a given Gushimisha hymn number.
  /// If the book is not Gushimisha or no originals exist, returns an empty list.
  List<OriginalHymn> getOriginals(String book, int hymnNumber) {
    if (book.toLowerCase() != 'gushimisha') {
      return const [];
    }
    return _hymnsByNumber[hymnNumber] ?? const [];
  }
}

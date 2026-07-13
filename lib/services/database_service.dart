import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/bible_verse.dart';
import '../models/hymn.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'gospel_hub.db');

    // Check if the database exists
    final exists = await databaseExists(path);
    bool shouldCopy = !exists;

    if (exists) {
      try {
        final db = await openDatabase(path, readOnly: true);
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM bible_verses'));
        // Try reading from english_verses to verify KJV translation table exists
        await db.rawQuery('SELECT COUNT(*) FROM english_verses');
        await db.close();
        if (count == null || count == 0) {
          print('Existing database is empty. Will overwrite.');
          shouldCopy = true;
        }
      } catch (e) {
        print('Existing database is invalid or lacks KJV translation table: $e. Will overwrite.');
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      print('Creating new copy from asset...');
      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      try {
        ByteData data = await rootBundle.load('assets/database/gospel_hub.db');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        // Write and flush the bytes written
        await File(path).writeAsBytes(bytes, flush: true);
        print('Database copied successfully!');
      } catch (e) {
        print('Error copying database asset: $e');
        throw Exception('Failed to initialize local database');
      }
    } else {
      print('Database already exists at: $path and is healthy.');
    }

    // Open the database
    return await openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS highlights (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id INTEGER NOT NULL UNIQUE,
            color_index INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id INTEGER NOT NULL UNIQUE,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS verse_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id INTEGER NOT NULL,
            tag_name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            UNIQUE(verse_id, tag_name)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reading_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            read_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hymn_playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hymn_playlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL,
            hymn_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            UNIQUE(playlist_id, hymn_id)
          )
        ''');
      },
    );
  }

  // ── Bible Queries ──────────────────────────────────────────────────────────

  Future<List<BibleVerse>> getChapterVerses(int bookNumber, int chapterNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bible_verses',
      where: 'book = ? AND chapter = ?',
      whereArgs: [bookNumber, chapterNumber],
      orderBy: 'verse',
    );
    return List.generate(maps.length, (i) => BibleVerse.fromMap(maps[i]));
  }

  Future<List<BibleVerse>> searchBible(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bible_verses',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'book, chapter, verse',
      limit: 100, // Safe limit for performance
    );
    return List.generate(maps.length, (i) => BibleVerse.fromMap(maps[i]));
  }

  // ── Hymn Queries ───────────────────────────────────────────────────────────

  Future<List<Hymn>> getHymnsByBook(String bookName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'book = ?',
      whereArgs: [bookName],
      orderBy: 'number',
    );
    return List.generate(maps.length, (i) => Hymn.fromMap(maps[i]));
  }

  Future<Hymn?> getHymnByBookAndNumber(String bookName, int number) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'book = ? AND number = ?',
      whereArgs: [bookName, number],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Hymn.fromMap(maps.first);
  }

  Future<List<Hymn>> searchHymns(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'title LIKE ? OR category LIKE ? OR lyrics LIKE ? OR number = ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', int.tryParse(query) ?? -1],
      orderBy: 'book, number',
      limit: 100,
    );
    return List.generate(maps.length, (i) => Hymn.fromMap(maps[i]));
  }

  // ── Favorite Queries ────────────────────────────────────────────────────────

  Future<void> addFavorite(String type, int itemId) async {
    final db = await database;
    // Check if already exists
    final List<Map<String, dynamic>> existing = await db.query(
      'favorites',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
    if (existing.isEmpty) {
      await db.insert('favorites', {
        'type': type,
        'item_id': itemId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> removeFavorite(String type, int itemId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
  }

  Future<bool> isFavorite(String type, int itemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
    return maps.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavoritesByType(String type) async {
    final db = await database;
    if (type == 'bible') {
      return await db.rawQuery('''
        SELECT f.id as favorite_id, v.*
        FROM favorites f
        JOIN bible_verses v ON f.item_id = v.id
        WHERE f.type = 'bible'
        ORDER BY f.created_at DESC
      ''');
    } else {
      return await db.rawQuery('''
        SELECT f.id as favorite_id, h.*
        FROM favorites f
        JOIN hymns h ON f.item_id = h.id
        WHERE f.type = 'hymn'
        ORDER BY f.created_at DESC
      ''');
    }
  }

  // ── Highlight Queries ──────────────────────────────────────────────────────

  Future<void> saveHighlight(int verseId, int colorIndex) async {
    final db = await database;
    await db.insert(
      'highlights',
      {
        'verse_id': verseId,
        'color_index': colorIndex,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeHighlight(int verseId) async {
    final db = await database;
    await db.delete(
      'highlights',
      where: 'verse_id = ?',
      whereArgs: [verseId],
    );
  }

  Future<Map<int, int>> getHighlightsForChapter(int bookNumber, int chapterNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT h.verse_id, h.color_index
      FROM highlights h
      JOIN bible_verses v ON h.verse_id = v.id
      WHERE v.book = ? AND v.chapter = ?
    ''', [bookNumber, chapterNumber]);

    return {for (var row in results) row['verse_id'] as int: row['color_index'] as int};
  }

  // ── Note Queries ───────────────────────────────────────────────────────────

  Future<void> saveNote(int verseId, String content) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'notes',
      {
        'verse_id': verseId,
        'content': content,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeNote(int verseId) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'verse_id = ?',
      whereArgs: [verseId],
    );
  }

  Future<String?> getNoteForVerse(int verseId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'notes',
      columns: ['content'],
      where: 'verse_id = ?',
      whereArgs: [verseId],
    );
    if (results.isEmpty) return null;
    return results.first['content'] as String;
  }

  Future<Map<int, String>> getNotesForChapter(int bookNumber, int chapterNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT n.verse_id, n.content
      FROM notes n
      JOIN bible_verses v ON n.verse_id = v.id
      WHERE v.book = ? AND v.chapter = ?
    ''', [bookNumber, chapterNumber]);

    return {for (var row in results) row['verse_id'] as int: row['content'] as String};
  }

  // ── Combined & Study Queries ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllNotesWithVerses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT n.id as note_id, n.content as note_content, n.updated_at, v.*
      FROM notes n
      JOIN bible_verses v ON n.verse_id = v.id
      ORDER BY n.updated_at DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAllHighlightsWithVerses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT h.id as highlight_id, h.color_index, h.created_at, v.*
      FROM highlights h
      JOIN bible_verses v ON h.verse_id = v.id
      ORDER BY h.created_at DESC
    ''');
  }

  // ── Raw Backup & Restore Queries ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllFavoritesRaw() async {
    final db = await database;
    return await db.query('favorites');
  }

  Future<List<Map<String, dynamic>>> getAllHighlightsRaw() async {
    final db = await database;
    return await db.query('highlights');
  }

  Future<List<Map<String, dynamic>>> getAllNotesRaw() async {
    final db = await database;
    return await db.query('notes');
  }

  Future<List<Map<String, dynamic>>> getAllVerseTagsRaw() async {
    final db = await database;
    return await db.query('verse_tags');
  }

  Future<List<Map<String, dynamic>>> getAllReadingHistoryRaw() async {
    final db = await database;
    return await db.query('reading_history');
  }

  Future<List<Map<String, dynamic>>> getAllHymnPlaylistsRaw() async {
    final db = await database;
    return await db.query('hymn_playlists');
  }

  Future<List<Map<String, dynamic>>> getAllHymnPlaylistItemsRaw() async {
    final db = await database;
    return await db.query('hymn_playlist_items');
  }

  Future<void> restoreBackup(
    List<dynamic> favorites,
    List<dynamic> highlights,
    List<dynamic> notes,
    List<dynamic>? tags,
    List<dynamic>? history,
    List<dynamic>? playlists,
    List<dynamic>? playlistItems,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing records
      await txn.delete('favorites');
      await txn.delete('highlights');
      await txn.delete('notes');
      await txn.delete('verse_tags');
      await txn.delete('reading_history');
      await txn.delete('hymn_playlists');
      await txn.delete('hymn_playlist_items');

      // Re-insert favorites
      for (var f in favorites) {
        if (f is Map) {
          await txn.insert(
            'favorites',
            Map<String, dynamic>.from(f),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Re-insert highlights
      for (var h in highlights) {
        if (h is Map) {
          await txn.insert(
            'highlights',
            Map<String, dynamic>.from(h),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Re-insert notes
      for (var n in notes) {
        if (n is Map) {
          await txn.insert(
            'notes',
            Map<String, dynamic>.from(n),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Re-insert tags
      if (tags != null) {
        for (var t in tags) {
          if (t is Map) {
            await txn.insert(
              'verse_tags',
              Map<String, dynamic>.from(t),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Re-insert history
      if (history != null) {
        for (var h in history) {
          if (h is Map) {
            await txn.insert(
              'reading_history',
              Map<String, dynamic>.from(h),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Re-insert playlists
      if (playlists != null) {
        for (var p in playlists) {
          if (p is Map) {
            await txn.insert(
              'hymn_playlists',
              Map<String, dynamic>.from(p),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Re-insert playlist items
      if (playlistItems != null) {
        for (var pi in playlistItems) {
          if (pi is Map) {
            await txn.insert(
              'hymn_playlist_items',
              Map<String, dynamic>.from(pi),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    });
  }

  // ── English Bible Queries ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEnglishChapterVerses(int bookNumber, int chapterNumber) async {
    final db = await database;
    return await db.query(
      'english_verses',
      where: 'book = ? AND chapter = ?',
      whereArgs: [bookNumber, chapterNumber],
      orderBy: 'verse',
    );
  }

  // ── Study Tags Queries ─────────────────────────────────────────────────────

  Future<void> addVerseTag(int verseId, String tagName) async {
    final db = await database;
    await db.insert(
      'verse_tags',
      {
        'verse_id': verseId,
        'tag_name': tagName,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeVerseTag(int verseId, String tagName) async {
    final db = await database;
    await db.delete(
      'verse_tags',
      where: 'verse_id = ? AND tag_name = ?',
      whereArgs: [verseId, tagName],
    );
  }

  Future<List<String>> getVerseTags(int verseId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'verse_tags',
      columns: ['tag_name'],
      where: 'verse_id = ?',
      whereArgs: [verseId],
      orderBy: 'tag_name',
    );
    return List.generate(results.length, (i) => results[i]['tag_name'] as String);
  }

  Future<Map<int, List<String>>> getTagsForChapter(int bookNumber, int chapterNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT t.verse_id, t.tag_name
      FROM verse_tags t
      JOIN bible_verses v ON t.verse_id = v.id
      WHERE v.book = ? AND v.chapter = ?
      ORDER BY t.tag_name
    ''', [bookNumber, chapterNumber]);

    final Map<int, List<String>> tagsMap = {};
    for (var row in results) {
      final verseId = row['verse_id'] as int;
      final tagName = row['tag_name'] as String;
      tagsMap.putIfAbsent(verseId, () => []).add(tagName);
    }
    return tagsMap;
  }

  Future<List<String>> getAllUniqueTags() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DISTINCT tag_name FROM verse_tags ORDER BY tag_name
    ''');
    return List.generate(results.length, (i) => results[i]['tag_name'] as String);
  }

  Future<List<Map<String, dynamic>>> getVersesByTag(String tagName) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.id as tag_row_id, t.tag_name, v.*
      FROM verse_tags t
      JOIN bible_verses v ON t.verse_id = v.id
      WHERE t.tag_name = ?
      ORDER BY t.created_at DESC
    ''', [tagName]);
  }

  // ── Hymn Categories Browse Queries ─────────────────────────────────────────

  Future<List<String>> getHymnCategories(String bookName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DISTINCT category 
      FROM hymns 
      WHERE book = ? AND category != '' 
      ORDER BY category
    ''', [bookName]);
    return List.generate(results.length, (i) => results[i]['category'] as String);
  }

  Future<List<Hymn>> getHymnsByCategory(String bookName, String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'book = ? AND category = ?',
      whereArgs: [bookName, category],
      orderBy: 'number',
    );
    return List.generate(maps.length, (i) => Hymn.fromMap(maps[i]));
  }

  // ── Devotion Stats & Reading History Queries ──────────────────────────────

  Future<void> logReading(int bookNumber, int chapterNumber) async {
    final db = await database;
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0).millisecondsSinceEpoch;
    final List<Map<String, dynamic>> existing = await db.query(
      'reading_history',
      where: 'book = ? AND chapter = ? AND read_at >= ?',
      whereArgs: [bookNumber, chapterNumber, todayStart],
    );
    if (existing.isEmpty) {
      await db.insert('reading_history', {
        'book': bookNumber,
        'chapter': chapterNumber,
        'read_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<Map<String, dynamic>> getDevotionStats() async {
    final db = await database;

    // 1. Total chapters read
    final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reading_history')) ?? 0;

    // 2. Streaks calculation
    final List<Map<String, dynamic>> history = await db.rawQuery('''
      SELECT DISTINCT (read_at / 86400000) as day
      FROM reading_history
      ORDER BY day DESC
    ''');

    int streak = 0;
    if (history.isNotEmpty) {
      final todayDay = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
      final latestReadDay = history.first['day'] as int;

      if (latestReadDay == todayDay || latestReadDay == todayDay - 1) {
        streak = 1;
        int expected = latestReadDay - 1;
        for (int i = 1; i < history.length; i++) {
          final current = history[i]['day'] as int;
          if (current == expected) {
            streak++;
            expected--;
          } else {
            break;
          }
        }
      }
    }

    // 3. Colors breakdown of highlights
    final List<Map<String, dynamic>> colorsBreakdown = await db.rawQuery('''
      SELECT color_index, COUNT(*) as count
      FROM highlights
      GROUP BY color_index
    ''');

    // 4. Recently read chapters
    final List<Map<String, dynamic>> recentlyRead = await db.rawQuery('''
      SELECT book, chapter, MAX(read_at) as last_read
      FROM reading_history
      GROUP BY book, chapter
      ORDER BY last_read DESC
      LIMIT 3
    ''');

    return {
      'total_chapters': totalCount,
      'streak': streak,
      'highlights_breakdown': colorsBreakdown,
      'recently_read': recentlyRead,
    };
  }

  // ── Hymn Playlists Queries ───────────────────────────────────────────────

  Future<int> createPlaylist(String name) async {
    final db = await database;
    return await db.insert(
      'hymn_playlists',
      {
        'name': name,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    return await db.query('hymn_playlists', orderBy: 'created_at DESC');
  }

  Future<List<Hymn>> getPlaylistHymns(int playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT h.*
      FROM hymn_playlist_items i
      JOIN hymns h ON i.hymn_id = h.id
      WHERE i.playlist_id = ?
      ORDER BY i.position ASC
    ''', [playlistId]);
    return List.generate(results.length, (i) => Hymn.fromMap(results[i]));
  }

  Future<void> addHymnToPlaylist(int playlistId, int hymnId) async {
    final db = await database;
    final maxPosResult = await db.rawQuery('''
      SELECT MAX(position) as max_pos FROM hymn_playlist_items WHERE playlist_id = ?
    ''', [playlistId]);
    final nextPos = (Sqflite.firstIntValue(maxPosResult) ?? -1) + 1;

    await db.insert(
      'hymn_playlist_items',
      {
        'playlist_id': playlistId,
        'hymn_id': hymnId,
        'position': nextPos,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeHymnFromPlaylist(int playlistId, int hymnId) async {
    final db = await database;
    await db.delete(
      'hymn_playlist_items',
      where: 'playlist_id = ? AND hymn_id = ?',
      whereArgs: [playlistId, hymnId],
    );
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'hymn_playlist_items',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      await txn.delete(
        'hymn_playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );
    });
  }
}
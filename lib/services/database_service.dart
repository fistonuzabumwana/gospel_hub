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
        await db.close();
        if (count == null || count == 0) {
          print('Existing database is empty. Will overwrite.');
          shouldCopy = true;
        }
      } catch (e) {
        print('Existing database is invalid or outdated: $e. Will overwrite.');
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
}
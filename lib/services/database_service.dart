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
    return await openDatabase(path, version: 1);
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
}
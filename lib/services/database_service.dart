import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bible_verse.dart';
import '../models/bible_book.dart';
import '../models/bible_version.dart';
import '../models/hymn.dart';
import '../models/hymn_category.dart';

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
    String path = join(await getDatabasesPath(), 'gospel_hub.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Bible versions table
    await db.execute('''
      CREATE TABLE bible_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_code TEXT NOT NULL,
        language_code TEXT NOT NULL,
        display_name TEXT NOT NULL,
        is_downloaded INTEGER NOT NULL DEFAULT 0,
        download_date INTEGER
      )
    ''');

    // Bible books table
    await db.execute('''
      CREATE TABLE bible_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_number INTEGER NOT NULL,
        book_name_en TEXT NOT NULL,
        book_name_kinyarwanda TEXT NOT NULL,
        book_name_french TEXT NOT NULL,
        testament TEXT NOT NULL,
        chapter_count INTEGER NOT NULL
      )
    ''');

    // Bible verses table
    await db.execute('''
      CREATE TABLE bible_verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_id INTEGER NOT NULL,
        book_id INTEGER NOT NULL,
        chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL,
        verse_text TEXT NOT NULL,
        FOREIGN KEY (version_id) REFERENCES bible_versions (id),
        FOREIGN KEY (book_id) REFERENCES bible_books (id)
      )
    ''');

    // Hymn categories table
    await db.execute('''
      CREATE TABLE hymn_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name_en TEXT NOT NULL,
        category_name_kinyarwanda TEXT NOT NULL,
        category_name_french TEXT NOT NULL
      )
    ''');

    // Hymns table
    await db.execute('''
      CREATE TABLE hymns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hymn_number INTEGER NOT NULL,
        title_en TEXT NOT NULL,
        title_kinyarwanda TEXT NOT NULL,
        title_french TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        lyrics_en TEXT NOT NULL,
        lyrics_kinyarwanda TEXT NOT NULL,
        lyrics_french TEXT NOT NULL,
        first_line TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES hymn_categories (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_bible_verses_version_book ON bible_verses(version_id, book_id)');
    await db.execute('CREATE INDEX idx_bible_verses_chapter ON bible_verses(chapter_number)');
    await db.execute('CREATE INDEX idx_hymns_category ON hymns(category_id)');
    await db.execute('CREATE INDEX idx_hymns_search ON hymns(title_en, first_line)');
  }

  // Bible Version methods
  Future<int> insertBibleVersion(BibleVersion version) async {
    final db = await database;
    return await db.insert('bible_versions', version.toMap());
  }

  Future<List<BibleVersion>> getBibleVersions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bible_versions');
    return List.generate(maps.length, (i) => BibleVersion.fromMap(maps[i]));
  }

  Future<void> updateBibleVersionDownloadStatus(int versionId, bool isDownloaded) async {
    final db = await database;
    await db.update(
      'bible_versions',
      {
        'is_downloaded': isDownloaded ? 1 : 0,
        'download_date': isDownloaded ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [versionId],
    );
  }

  // Bible Book methods
  Future<int> insertBibleBook(BibleBook book) async {
    final db = await database;
    return await db.insert('bible_books', book.toMap());
  }

  Future<List<BibleBook>> getBibleBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bible_books', orderBy: 'book_number');
    return List.generate(maps.length, (i) => BibleBook.fromMap(maps[i]));
  }

  // Bible Verse methods
  Future<int> insertBibleVerse(BibleVerse verse) async {
    final db = await database;
    return await db.insert('bible_verses', verse.toMap());
  }

  Future<List<BibleVerse>> getChapterVerses(int versionId, int bookId, int chapterNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bible_verses',
      where: 'version_id = ? AND book_id = ? AND chapter_number = ?',
      whereArgs: [versionId, bookId, chapterNumber],
      orderBy: 'verse_number',
    );
    return List.generate(maps.length, (i) => BibleVerse.fromMap(maps[i]));
  }

  // Hymn Category methods
  Future<int> insertHymnCategory(HymnCategory category) async {
    final db = await database;
    return await db.insert('hymn_categories', category.toMap());
  }

  Future<List<HymnCategory>> getHymnCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('hymn_categories');
    return List.generate(maps.length, (i) => HymnCategory.fromMap(maps[i]));
  }

  // Hymn methods
  Future<int> insertHymn(Hymn hymn) async {
    final db = await database;
    return await db.insert('hymns', hymn.toMap());
  }

  Future<List<Hymn>> getHymnsByCategory(int categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'hymn_number',
    );
    return List.generate(maps.length, (i) => Hymn.fromMap(maps[i]));
  }

  Future<List<Hymn>> searchHymns(String searchQuery) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hymns',
      where: 'title_en LIKE ? OR title_kinyarwanda LIKE ? OR title_french LIKE ? OR first_line LIKE ?',
      whereArgs: ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%'],
      orderBy: 'hymn_number',
    );
    return List.generate(maps.length, (i) => Hymn.fromMap(maps[i]));
  }

  // Utility methods
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
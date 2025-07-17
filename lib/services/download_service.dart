import 'database_service.dart';
import 'api_service.dart';
import '../models/bible_version.dart';
import '../models/bible_book.dart';
import '../models/bible_verse.dart';

class DownloadService {
  final DatabaseService _databaseService = DatabaseService();

  // Download and store a Bible version
  Future<void> downloadBibleVersion(String bibleId, String languageCode, String displayName) async {
    try {
      // Insert Bible version record
      final bibleVersion = BibleVersion(
        versionCode: bibleId,
        languageCode: languageCode,
        displayName: displayName,
        isDownloaded: false,
      );

      final versionId = await _databaseService.insertBibleVersion(bibleVersion);

      // Get books for this Bible version
      final booksData = await ApiService.getBibleBooks(bibleId);

      // Process each book
      for (var bookData in booksData) {
        final bookId = await _processBook(bookData);

        // Get chapters for this book
        final chaptersData = await ApiService.getBookChapters(bibleId, bookData['id']);

        // Process each chapter
        for (var chapterData in chaptersData) {
          await _processChapter(bibleId, versionId, bookId, chapterData);
        }
      }

      // Mark version as downloaded
      await _databaseService.updateBibleVersionDownloadStatus(versionId, true);

    } catch (e) {
      throw Exception('Failed to download Bible version: $e');
    }
  }

  // Process and store a book
  Future<int> _processBook(Map<String, dynamic> bookData) async {
    // You'll need to map API book names to multilingual names
    // For now, using English names as placeholder
    final book = BibleBook(
      bookNumber: _getBookNumber(bookData['id']),
      bookNameEn: bookData['name'],
      bookNameKinyarwanda: bookData['name'], // TODO: Add translations
      bookNameFrench: bookData['name'], // TODO: Add translations
      testament: _getTestament(bookData['id']),
      chapterCount: 0, // Will be updated when processing chapters
    );

    return await _databaseService.insertBibleBook(book);
  }

  // Process and store verses for a chapter
  Future<void> _processChapter(String bibleId, int versionId, int bookId, Map<String, dynamic> chapterData) async {
    try {
      final versesData = await ApiService.getChapterVerses(bibleId, chapterData['id']);

      for (var verseData in versesData) {
        final verseText = ApiService.cleanVerseText(verseData['content'] ?? '');

        final verse = BibleVerse(
          versionId: versionId,
          bookId: bookId,
          chapterNumber: _extractChapterNumber(chapterData['id']),
          verseNumber: _extractVerseNumber(verseData['id']),
          verseText: verseText,
        );

        await _databaseService.insertBibleVerse(verse);
      }
    } catch (e) {
      print('Error processing chapter ${chapterData['id']}: $e');
    }
  }

  // Helper methods
  int _getBookNumber(String bookId) {
    // Map API book IDs to book numbers (1-66)
    final bookNumbers = {
      'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5,
      'JOS': 6, 'JDG': 7, 'RUT': 8, '1SA': 9, '2SA': 10,
      '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15,
      'NEH': 16, 'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20,
      'ECC': 21, 'SNG': 22, 'ISA': 23, 'JER': 24, 'LAM': 25,
      'EZK': 26, 'DAN': 27, 'HOS': 28, 'JOL': 29, 'AMO': 30,
      'OBA': 31, 'JON': 32, 'MIC': 33, 'NAM': 34, 'HAB': 35,
      'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39, 'MAT': 40,
      'MRK': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44, 'ROM': 45,
      '1CO': 46, '2CO': 47, 'GAL': 48, 'EPH': 49, 'PHP': 50,
      'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54, '2TI': 55,
      'TIT': 56, 'PHM': 57, 'HEB': 58, 'JAS': 59, '1PE': 60,
      '2PE': 61, '1JN': 62, '2JN': 63, '3JN': 64, 'JUD': 65,
      'REV': 66,
    };
    return bookNumbers[bookId] ?? 1;
  }

  String _getTestament(String bookId) {
    final oldTestament = ['GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', '1SA', '2SA', '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO', 'ECC', 'SNG', 'ISA', 'JER', 'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO', 'OBA', 'JON', 'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL'];
    return oldTestament.contains(bookId) ? 'OLD' : 'NEW';
  }

  int _extractChapterNumber(String chapterId) {
    // Extract chapter number from chapter ID (e.g., "GEN.1" -> 1)
    final parts = chapterId.split('.');
    return int.tryParse(parts.last) ?? 1;
  }

  int _extractVerseNumber(String verseId) {
    // Extract verse number from verse ID (e.g., "GEN.1.1" -> 1)
    final parts = verseId.split('.');
    return int.tryParse(parts.last) ?? 1;
  }
}
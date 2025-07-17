import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.scripture.api.bible/v1';
  static const String apiKey = '43a321a49fef849c626aaaa07f99222d';

  static final Map<String, String> headers = {
    'api-key': apiKey,
    'Content-Type': 'application/json',
  };

  // Get all available Bible versions
  static Future<List<dynamic>> getBibleVersions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load Bible versions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching Bible versions: $e');
    }
  }

  // Get books for a specific Bible version
  static Future<List<dynamic>> getBibleBooks(String bibleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/books'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load Bible books: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching Bible books: $e');
    }
  }

  // Get chapters for a specific book
  static Future<List<dynamic>> getBookChapters(String bibleId, String bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/books/$bookId/chapters'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load chapters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching chapters: $e');
    }
  }

  // Get verses for a specific chapter
  static Future<List<dynamic>> getChapterVerses(String bibleId, String chapterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/chapters/$chapterId/verses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load verses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching verses: $e');
    }
  }

  // Get a specific verse
  static Future<Map<String, dynamic>> getVerse(String bibleId, String verseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/verses/$verseId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load verse: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching verse: $e');
    }
  }

  // Search verses in a Bible
  static Future<List<dynamic>> searchVerses(String bibleId, String query, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/search?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['verses'] ?? [];
      } else {
        throw Exception('Failed to search verses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching verses: $e');
    }
  }

  // Get passage (multiple verses)
  static Future<Map<String, dynamic>> getPassage(String bibleId, String passageId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bibles/$bibleId/passages/$passageId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load passage: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching passage: $e');
    }
  }

  // Helper method to clean HTML tags from verse text
  static String cleanVerseText(String text) {
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    return text.trim();
  }
}
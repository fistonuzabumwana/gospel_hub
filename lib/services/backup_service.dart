import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupService {
  static final BackupService instance = BackupService._internal();

  late final GoogleSignIn _googleSignIn;

  final ValueNotifier<GoogleSignInAccount?> currentUser = ValueNotifier<GoogleSignInAccount?>(null);

  BackupService._internal() {
    _googleSignIn = GoogleSignIn(
      scopes: [
        drive.DriveApi.driveAppdataScope,
        'email',
      ],
    );

    _googleSignIn.onCurrentUserChanged.listen((account) {
      currentUser.value = account;
    });

    // Attempt silent sign-in on initialization
    _googleSignIn.signInSilently().then((account) {
      if (account != null) {
        currentUser.value = account;
      }
    }).catchError((e) {
      debugPrint('Silent Sign-In Error: $e');
    });
  }

  bool get isSignedIn => currentUser.value != null;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      currentUser.value = null;
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
    }
  }

  /// Backup app database tables and shared preferences to Google Drive appDataFolder
  Future<bool> backupToGoogleDrive() async {
    final account = currentUser.value;
    if (account == null) {
      debugPrint('Backup failed: User is not signed in.');
      return false;
    }

    try {
      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      final dbService = DatabaseService();

      // Retrieve all local user data tables
      final favorites = await dbService.getAllFavoritesRaw();
      final highlights = await dbService.getAllHighlightsRaw();
      final notes = await dbService.getAllNotesRaw();
      final tags = await dbService.getAllVerseTagsRaw();
      final history = await dbService.getAllReadingHistoryRaw();
      final playlists = await dbService.getAllHymnPlaylistsRaw();
      final playlistItems = await dbService.getAllHymnPlaylistItemsRaw();

      // Retrieve shared preferences
      final prefs = await SharedPreferences.getInstance();
      final preferences = {
        'app_language': prefs.getString('app_language') ?? 'en',
        'bible_language': prefs.getString('bible_language') ?? 'KJV_EN',
        'dark_mode': prefs.getBool('dark_mode'),
        'last_read_book_number': prefs.getInt('last_read_book_number'),
        'last_read_chapter': prefs.getInt('last_read_chapter'),
      };

      // Wrap all backup data
      final backupData = {
        'backup_version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'preferences': preferences,
        'database': {
          'favorites': favorites,
          'highlights': highlights,
          'notes': notes,
          'verse_tags': tags,
          'reading_history': history,
          'hymn_playlists': playlists,
          'hymn_playlist_items': playlistItems,
        }
      };

      final jsonString = json.encode(backupData);
      final jsonBytes = utf8.encode(jsonString);

      // Search for an existing backup file in the appDataFolder
      final filesList = await driveApi.files.list(
        q: "name = 'gospel_hub_backup.json' and trashed = false",
        spaces: 'appDataFolder',
      );

      final existingFiles = filesList.files;
      final driveFile = drive.File()
        ..name = 'gospel_hub_backup.json';

      final media = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      );

      if (existingFiles != null && existingFiles.isNotEmpty) {
        // Update the existing backup file
        final fileId = existingFiles.first.id!;
        await driveApi.files.update(
          driveFile,
          fileId,
          uploadMedia: media,
        );
        debugPrint('Updated existing Google Drive backup.');
      } else {
        // Create a new backup file
        driveFile.parents = ['appDataFolder'];
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint('Created new Google Drive backup.');
      }

      return true;
    } catch (e) {
      debugPrint('Google Drive Backup Error: $e');
      return false;
    }
  }

  /// Restore database tables and shared preferences from Google Drive backup
  Future<bool> restoreFromGoogleDrive() async {
    final account = currentUser.value;
    if (account == null) {
      debugPrint('Restore failed: User is not signed in.');
      return false;
    }

    try {
      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      // Search for the backup file in appDataFolder
      final filesList = await driveApi.files.list(
        q: "name = 'gospel_hub_backup.json' and trashed = false",
        spaces: 'appDataFolder',
      );

      final files = filesList.files;
      if (files == null || files.isEmpty) {
        debugPrint('Restore failed: No backup file found on Google Drive.');
        return false;
      }

      final fileId = files.first.id!;

      // Download backup content
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await for (final chunk in media.stream) {
        dataBytes.addAll(chunk);
      }

      final jsonString = utf8.decode(dataBytes);
      final backupData = json.decode(jsonString);

      if (backupData is! Map) {
        debugPrint('Restore failed: Invalid backup data format.');
        return false;
      }

      // Restore preferences
      final preferences = backupData['preferences'];
      if (preferences is Map) {
        final prefs = await SharedPreferences.getInstance();
        if (preferences.containsKey('app_language')) {
          await prefs.setString('app_language', preferences['app_language'] as String);
        }
        if (preferences.containsKey('bible_language')) {
          await prefs.setString('bible_language', preferences['bible_language'] as String);
        }
        if (preferences.containsKey('dark_mode')) {
          final val = preferences['dark_mode'];
          if (val == null) {
            await prefs.remove('dark_mode');
          } else {
            await prefs.setBool('dark_mode', val as bool);
          }
        }
        if (preferences.containsKey('last_read_book_number') && preferences['last_read_book_number'] != null) {
          await prefs.setInt('last_read_book_number', preferences['last_read_book_number'] as int);
        }
        if (preferences.containsKey('last_read_chapter') && preferences['last_read_chapter'] != null) {
          await prefs.setInt('last_read_chapter', preferences['last_read_chapter'] as int);
        }
      }

      // Restore SQLite database tables
      final databaseData = backupData['database'];
      if (databaseData is Map) {
        final dbService = DatabaseService();
        await dbService.restoreBackup(
          databaseData['favorites'] ?? [],
          databaseData['highlights'] ?? [],
          databaseData['notes'] ?? [],
          databaseData['verse_tags'] ?? [],
          databaseData['reading_history'] ?? [],
          databaseData['hymn_playlists'] ?? [],
          databaseData['hymn_playlist_items'] ?? [],
        );
      }

      debugPrint('Restore completed successfully.');
      return true;
    } catch (e) {
      debugPrint('Google Drive Restore Error: $e');
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../services/database_service.dart';
import '../utils/app_constants.dart';
import '../models/bible_version.dart';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  final DownloadService _downloadService = DownloadService();
  final DatabaseService _databaseService = DatabaseService();
  List<BibleVersion> _bibleVersions = [];
  bool _isLoading = true;
  String? _downloadingVersion;

  @override
  void initState() {
    super.initState();
    _loadBibleVersions();
  }

  Future<void> _loadBibleVersions() async {
    try {
      final versions = await _databaseService.getBibleVersions();
      setState(() {
        _bibleVersions = versions;
        _isLoading = false;
      });

      // If no versions exist, initialize them
      if (versions.isEmpty) {
        await _initializeBibleVersions();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load Bible versions: $e');
    }
  }

  Future<void> _initializeBibleVersions() async {
    try {
      for (final entry in AppConstants.bibleVersions.entries) {
        final version = BibleVersion(
          versionCode: entry.value,
          languageCode: entry.key.split('_').last.toLowerCase(),
          displayName: AppConstants.bibleLanguageNames[entry.key] ?? entry.key,
          isDownloaded: false,
        );
        await _databaseService.insertBibleVersion(version);
      }
      await _loadBibleVersions();
    } catch (e) {
      _showErrorDialog('Failed to initialize Bible versions: $e');
    }
  }

  Future<void> _downloadBibleVersion(BibleVersion version) async {
    setState(() {
      _downloadingVersion = version.versionCode;
    });

    try {
      await _downloadService.downloadBibleVersion(
        version.versionCode,
        version.languageCode,
        version.displayName,
      );

      await _loadBibleVersions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${version.displayName} downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to download ${version.displayName}: $e');
    } finally {
      setState(() {
        _downloadingVersion = null;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _bibleVersions.length,
        itemBuilder: (context, index) {
          final version = _bibleVersions[index];
          final isDownloading = _downloadingVersion == version.versionCode;

          return Card(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              leading: Icon(
                version.isDownloaded
                    ? Icons.download_done
                    : Icons.download,
                color: version.isDownloaded
                    ? Colors.green
                    : Theme.of(context).primaryColor,
              ),
              title: Text(version.displayName),
              subtitle: Text(
                version.isDownloaded
                    ? 'Downloaded on ${version.downloadDate?.toString().split(' ')[0] ?? 'Unknown'}'
                    : 'Not downloaded',
              ),
              trailing: isDownloading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : version.isDownloaded
                  ? Icon(
                Icons.check_circle,
                color: Colors.green,
              )
                  : ElevatedButton(
                onPressed: () => _downloadBibleVersion(version),
                child: const Text('Download'),
              ),
            ),
          );
        },
      ),
    );
  }
}
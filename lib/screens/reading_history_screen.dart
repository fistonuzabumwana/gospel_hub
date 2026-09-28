import 'package:flutter/material.dart';
import '../models/bible_book.dart';
import '../services/database_service.dart';
import '../services/app_localizations.dart';
import '../widgets/truncated_verse_text.dart';

class ReadingHistoryScreen extends StatefulWidget {
  final Function(BibleBook book, int chapter, int verse) onNavigateToVerse;

  const ReadingHistoryScreen({
    super.key,
    required this.onNavigateToVerse,
  });

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final items = await _dbService.getRecentlyReadHistory(limit: 100);
      if (mounted) {
        setState(() {
          _history = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.translate('reading_history_clear')),
        content: Text(AppLocalizations.translate('reading_history_clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.translate('settings_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.translate('settings_restore_btn'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.clearReadingHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.translate('reading_history_cleared'))),
        );
        _loadHistory();
      }
    }
  }

  String _formatTimestamp(int timestamp, String lang) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(itemDate).inDays;

    final hourStr = date.hour.toString().padLeft(2, '0');
    final minuteStr = date.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (diffDays == 0) {
      return lang == 'en' ? 'Today $timeStr' : 'Uyu munsi $timeStr';
    } else if (diffDays == 1) {
      return lang == 'en' ? 'Yesterday $timeStr' : 'Ejo $timeStr';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppLocalizations.translate('reading_history_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              if (_history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: AppLocalizations.translate('reading_history_clear'),
                  onPressed: _clearHistory,
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDark ? const Color(0xFF60A5FA) : primaryColor).withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                Icons.history_toggle_off_rounded,
                                size: 48,
                                color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.translate('reading_history_empty'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.translate('reading_history_empty_desc'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final bookObj = BibleBook.getByNumber(item['book']);
                        final verseNum = (item['verse'] as int?) ?? 1;
                        final verseText = (currentLang == 'en'
                            ? (item['verse_text_en'] ?? item['verse_text'])
                            : item['verse_text']) as String? ?? '';
                        final bookName = bookObj.getDisplayName(currentLang == 'en' ? 'english' : 'kinyarwanda');
                        final refTitle = '$bookName ${item['chapter']}:$verseNum';
                        final timestamp = item['last_read'] as int?;
                        final timeString = timestamp != null ? _formatTimestamp(timestamp, currentLang) : '';

                        return Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: (isDark ? const Color(0xFF60A5FA) : primaryColor).withValues(alpha: 0.1),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onNavigateToVerse(bookObj, item['chapter'], verseNum);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: (isDark ? const Color(0xFF60A5FA) : primaryColor).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.history_rounded,
                                      color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                refTitle,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (timeString.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                timeString,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (verseText.trim().isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          TruncatedVerseText(
                                            text: verseText.trim(),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}

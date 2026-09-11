import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible_book.dart';
import '../../services/database_service.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/home_screen.dart';

class SavedStudyTab extends StatefulWidget {
  final List<Map<String, dynamic>> journalNotes;
  final List<Map<String, dynamic>> savedNotes;
  final List<Map<String, dynamic>> savedHighlights;
  final List<String> uniqueTags;
  final DatabaseService dbService;
  final VoidCallback onDataChanged;
  
  // These are passed down from HomeScreen to initialize the tab correctly
  final String initialStudySubTab;
  final Function(String) onStudySubTabChanged;

  const SavedStudyTab({
    super.key,
    required this.journalNotes,
    required this.savedNotes,
    required this.savedHighlights,
    required this.uniqueTags,
    required this.dbService,
    required this.onDataChanged,
    required this.initialStudySubTab,
    required this.onStudySubTabChanged,
  });

  @override
  State<SavedStudyTab> createState() => _SavedStudyTabState();
}

class _SavedStudyTabState extends State<SavedStudyTab> {
  final TextEditingController _journalSearchController = TextEditingController();
  String _journalSearchQuery = '';
  String? _selectedTagFilter;
  List<Map<String, dynamic>> _taggedVerses = [];

  Future<void> _loadTaggedVerses(String tagName) async {
    final verses = await widget.dbService.getVersesByTag(tagName);
    if (mounted) {
      setState(() {
        _taggedVerses = verses;
      });
    }
  }

  // Highlight colors match what's in bible_reader_screen
  final List<Color> _highlightColors = [
    Colors.yellow,
    Colors.pink,
    Colors.lightGreen,
    Colors.lightBlue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.deepOrange,
  ];

  @override
  void dispose() {
    _journalSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildStudySubNavBar(),
          Expanded(
            child: _buildStudySubTabContent(),
          ),
        ],
      ),
      floatingActionButton: widget.initialStudySubTab == 'journal'
          ? FloatingActionButton.extended(
              onPressed: () => _showJournalEditor(),
              icon: const Icon(Icons.add),
              label: Text(localeNotifier.value == 'en' ? 'New Journal' : 'Inyandiko Nshya'),
            )
          : null,
    );
  }

  Widget _buildStudySubNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = localeNotifier.value;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSubTabButton('journal', locale == 'en' ? 'Journal' : 'Inyandiko', Icons.edit_note),
          _buildSubTabButton('verse_notes', locale == 'en' ? 'Verse Notes' : 'Inyandiko z\'Umurongo', Icons.menu_book),
          _buildSubTabButton('highlights', locale == 'en' ? 'Highlights' : 'Ibimurikirwa', Icons.format_color_fill),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String tab, String label, IconData icon) {
    final isSelected = widget.initialStudySubTab == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected 
        ? Colors.white 
        : (isDark ? Colors.grey[350]! : const Color(0xFF4B5563));
        
    return Expanded(
      child: InkWell(
        onTap: () => widget.onStudySubTabChanged(tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? const Color(0xFF3B82F6) : Theme.of(context).primaryColor)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudySubTabContent() {
    switch (widget.initialStudySubTab) {
      case 'journal':
        return _buildJournalNotesList();
      case 'verse_notes':
        return _buildVerseNotesList();
      case 'highlights':
        return _buildHighlightsList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildJournalNotesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = localeNotifier.value;
    
    // Filter notes based on search query
    final filteredNotes = _journalSearchQuery.trim().isEmpty
        ? widget.journalNotes
        : widget.journalNotes.where((note) {
            final t = (note['title'] ?? '').toString().toLowerCase();
            final c = (note['content'] ?? '').toString().toLowerCase();
            final q = _journalSearchQuery.toLowerCase();
            return t.contains(q) || c.contains(q);
          }).toList();

    if (widget.journalNotes.isEmpty) {
      return _buildEmptyState(
        locale == 'en' 
            ? 'Your study journal is empty. Click "+" to start writing.' 
            : 'Nta nyandiko z\'icyigisho ufite. Kanda "+" ngo wandike inyandiko nshya.'
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _journalSearchController,
            onChanged: (val) => setState(() => _journalSearchQuery = val),
            decoration: InputDecoration(
              hintText: locale == 'en' ? 'Search journal...' : 'Shakisha inyandiko...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _journalSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _journalSearchController.clear();
                        setState(() => _journalSearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredNotes.isEmpty
              ? const Center(child: Text('Nta nyandiko zihuye n\'ibyo ushaka zibonetse.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    final dateStr = DateTime.fromMillisecondsSinceEpoch(note['updated_at'] ?? note['created_at'])
                        .toLocal()
                        .toString()
                        .substring(0, 16);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: context.appColors.accent.withValues(alpha: 0.1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showJournalEditor(note: note),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note['title'] ?? 'Nta mutwe',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                                        onPressed: () {
                                            SharePlus.instance.share(ShareParams(text: '${note['title'] ?? ""}\n\n${note['content'] ?? ""}'));
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Gusiba inyandiko'),
                                              content: const Text('Urashaka gusiba iyi nyandiko rwose?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Reka'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Siba', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await widget.dbService.deleteJournalNote(note['id']);
                                            widget.onDataChanged();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                note['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF4B5563),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showJournalEditor({Map<String, dynamic>? note}) {
    final titleController = TextEditingController(text: note?['title'] ?? '');
    final contentController = TextEditingController(text: note?['content'] ?? '');
    final isEdit = note != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Kora inyandiko (Edit Note)' : 'Inyandiko nshya (New Note)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              TextField(
                controller: titleController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Umutwe w\'inyandiko (Title)...',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: contentController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Andika hano (Write note content)...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();
                    if (content.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nta kintu cyanditswe!')),
                      );
                      return;
                    }
                    final finalTitle = title.isEmpty ? 'Nta mutwe' : title;
                    if (isEdit) {
                      await widget.dbService.updateJournalNote(note['id'], finalTitle, content);
                    } else {
                      await widget.dbService.insertJournalNote(finalTitle, content);
                    }
                    widget.onDataChanged();
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Bika (Save Note)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerseNotesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = localeNotifier.value;
    final hasNotes = widget.savedNotes.isNotEmpty;
    final hasTags = widget.uniqueTags.isNotEmpty;

    if (!hasNotes && !hasTags) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_study'));
    }

    return Column(
      children: [
        if (hasTags)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.uniqueTags.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedTagFilter == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('Zose (All)', style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedTagFilter = null;
                        });
                        widget.onDataChanged(); // Optionally force refresh, though setState here is enough
                      },
                    ),
                  );
                }

                final tag = widget.uniqueTags[index - 1];
                final isSelected = _selectedTagFilter == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTagFilter = tag;
                        });
                        _loadTaggedVerses(tag);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _selectedTagFilter != null
              ? _buildTaggedVersesList()
              : widget.savedNotes.isEmpty
                  ? _buildEmptyState(
                      locale == 'en' 
                          ? 'No verse notes saved. Tap and hold a verse in reader to add notes.' 
                          : 'Nta nyandiko z\'umurongo ufite.'
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: widget.savedNotes.map((note) {
                        final bookObj = BibleBook.getByNumber(note['book']);
                        final refStr = '${bookObj.name} ${note['chapter']}:${note['verse']}';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: context.appColors.accent.withValues(alpha: 0.1),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              final parentState = context.findAncestorStateOfType<HomeScreenState>();
                              parentState?.navigateToBibleVerse(bookObj, note['chapter'], note['verse']);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: context.appColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          refStr,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: context.appColors.accent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                                            onPressed: () {
                                                SharePlus.instance.share(ShareParams(text: 'Inyandiko z\'umurongo kuri $refStr:\n"${note['text']}"\n\nInyandiko: ${note['note_content']}'));
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () async {
                                              await widget.dbService.removeNote(note['id']);
                                              widget.onDataChanged();
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    note['note_content'],
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF242424) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF333333) : const Color(0xFFF3F4F6),
                                      ),
                                    ),
                                    child: Text(
                                      note['text'],
                                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, fontFamily: 'serif', height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildHighlightsList() {
    final locale = localeNotifier.value;
    
    if (widget.savedHighlights.isEmpty) {
      return _buildEmptyState(
        locale == 'en' 
            ? 'No highlights saved. Tap a verse in reader to highlight it.' 
            : 'Nta bintu bimuritswe ufite.'
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.savedHighlights.length,
      itemBuilder: (context, index) {
        final hl = widget.savedHighlights[index];
        final bookObj = BibleBook.getByNumber(hl['book']);
        final refStr = '${bookObj.name} ${hl['chapter']}:${hl['verse']}';
        final colorIndex = hl['color_index'] as int? ?? 0;
        final safeIndex = (colorIndex >= 0 && colorIndex < _highlightColors.length) ? colorIndex : 0;
        final highlightColor = _highlightColors[safeIndex];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: context.appColors.accent.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: () {
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToBibleVerse(bookObj, hl['chapter'], hl['verse']);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: highlightColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.appColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              refStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.appColors.accent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                            onPressed: () {
                              SharePlus.instance.share(ShareParams(text: '"${hl['text']}"\n\n— $refStr'));
                            },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () async {
                              await widget.dbService.removeHighlight(hl['id']);
                              widget.onDataChanged();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hl['text'],
                    style: const TextStyle(fontSize: 14, fontFamily: 'serif', height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaggedVersesList() {
    if (_taggedVerses.isEmpty) {
      return _buildEmptyState('Nta mirongo ifite iki kimenyetso.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _taggedVerses.length,
      itemBuilder: (context, index) {
        final item = _taggedVerses[index];
        final bookObj = BibleBook.getByNumber(item['book']);
        final refStr = '${bookObj.name} ${item['chapter']}:${item['verse']}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              item['text'],
              style: const TextStyle(fontSize: 14, fontFamily: 'serif', height: 1.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                children: [
                  Text(
                    refStr,
                    style: TextStyle(fontWeight: FontWeight.bold, color: context.appColors.accent, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.appColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['tag_name'],
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.appColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await widget.dbService.removeVerseTag(item['verse_id'] ?? item['id'], item['tag_name']);
                widget.onDataChanged();
              },
            ),
            onTap: () {
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToBibleVerse(bookObj, item['chapter'], item['verse']);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible_book.dart';
import '../../models/bible_verse.dart';
import '../../services/database_service.dart';
import '../../services/app_localizations.dart';

class VerseActionsModal {
  static void show(
    BuildContext context, {
    required BibleVerse verse,
    required bool isFavInitial,
    required int? activeHighlightIndex,
    required String? noteText,
    required List<String>? verseTags,
    required BibleBook selectedBook,
    required int selectedChapter,
    required String translationMode,
    required DatabaseService dbService,
    required List<Color> highlightColors,
    required void Function(int) onHighlightAdded,
    required VoidCallback onHighlightRemoved,
    required void Function(bool) onFavoriteToggled,
    required void Function(String) onTagRemoved,
    required VoidCallback onNoteRemoved,
    required void Function(BibleVerse, StateSetter) showAddTagDialog,
    required void Function(BibleVerse, String?, StateSetter) showNoteEditDialog,
    required void Function(BibleVerse) speakVerse,
    required Future<bool?> Function() showDeleteConfirmDialog,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool localIsFav = isFavInitial;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedBook.getDisplayName(translationMode)} ${verse.chapter}:${verse.verse}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verse.text,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Highlight Colors Selector ──
                  const Text('Guhitira umurongo (Highlight):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: highlightColors.length + 1,
                      itemBuilder: (context, index) {
                        if (index == highlightColors.length) {
                          return GestureDetector(
                            onTap: () async {
                              await dbService.removeHighlight(verse.id!);
                              onHighlightRemoved();
                              setModalState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400),
                                color: Colors.transparent,
                              ),
                              child: const Icon(Icons.format_color_reset, size: 18, color: Colors.grey),
                            ),
                          );
                        }

                        final color = highlightColors[index];
                        final isSelected = activeHighlightIndex == index;

                        return GestureDetector(
                          onTap: () async {
                            await dbService.saveHighlight(verse.id!, index);
                            onHighlightAdded(index);
                            setModalState(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                                width: isSelected ? 3.0 : 1.0,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Study Tags Section ──
                  const Text('Ibimenyetso (Tags):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...?verseTags?.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 12),
                          onDeleted: () async {
                            await dbService.removeVerseTag(verse.id!, tag);
                            onTagRemoved(tag);
                            setModalState(() {});
                          },
                        );
                      }),
                      ActionChip(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('Ongeraho', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showAddTagDialog(verse, setModalState);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Actions Row ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ModalActionButton(
                          icon: localIsFav ? Icons.favorite : Icons.favorite_border,
                          label: localIsFav ? 'Kuraho' : 'Bika',
                          color: localIsFav ? Colors.red : null,
                          onTap: () async {
                            if (localIsFav) {
                              await dbService.removeFavorite('bible', verse.id!);
                            } else {
                              await dbService.addFavorite('bible', verse.id!);
                            }
                            localIsFav = !localIsFav;
                            onFavoriteToggled(localIsFav);
                            setModalState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(localIsFav ? 'Yabitswe mu Byatoranyijwe!' : 'Mukuraho!'),
                                  duration: const Duration(seconds: 1),
                                )
                              );
                            }
                          },
                        ),
                        ModalActionButton(
                          icon: Icons.copy,
                          label: 'Kopi',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: '${verse.text} (${selectedBook.getDisplayName(translationMode)} ${verse.chapter}:${verse.verse})'));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.translate('toast_verse_copied')), duration: const Duration(seconds: 1))
                            );
                          },
                        ),
                        ModalActionButton(
                          icon: Icons.share,
                          label: 'Sangira',
                          onTap: () {
                            Navigator.pop(context);
                            SharePlus.instance.share(ShareParams(text: '${verse.text}\n\n— ${selectedBook.getDisplayName(translationMode)} ${verse.chapter}:${verse.verse}'));
                          },
                        ),
                        ModalActionButton(
                          icon: Icons.edit_note,
                          label: 'Icyigisho',
                          onTap: () {
                            showNoteEditDialog(verse, noteText, setModalState);
                          },
                        ),
                        ModalActionButton(
                          icon: Icons.volume_up_outlined,
                          label: 'Soma',
                          onTap: () {
                            Navigator.pop(context);
                            speakVerse(verse);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Note Preview Area ──
                  if (noteText != null && noteText.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Icyigisho cyabitswe (Note):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0.5,
                      color: isDark ? const Color(0xFF1B1D1B) : const Color(0xFFF0F5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              noteText,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Hindura', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    showNoteEditDialog(verse, noteText, setModalState);
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: const Text('Siba', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  onPressed: () async {
                                    final confirm = await showDeleteConfirmDialog();
                                    if (confirm == true) {
                                      await dbService.removeNote(verse.id!);
                                      onNoteRemoved();
                                      setModalState(() {});
                                    }
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ModalActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const ModalActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

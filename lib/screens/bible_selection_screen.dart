import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/app_localizations.dart';

class BibleVersion {
  final String id;
  final String name;
  final String language;
  final List<Color> coverGradient;
  final String abbrev;
  final String imagePath;

  const BibleVersion({
    required this.id,
    required this.name,
    required this.language,
    required this.coverGradient,
    required this.abbrev,
    required this.imagePath,
  });
}

class BibleSelectionScreen extends StatelessWidget {
  final VoidCallback onBibleSelected;

  const BibleSelectionScreen({
    super.key,
    required this.onBibleSelected,
  });

  static const List<BibleVersion> protestantBibles = [
    BibleVersion(
      id: 'BY',
      name: 'Bibiliya Yera',
      language: 'Kinyarwanda',
      coverGradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      abbrev: 'BY',
      imagePath: 'assets/bible/logos/bibiriya_yera_kinyarwanda.png',
    ),
    BibleVersion(
      id: 'II',
      name: 'Ijambo ry\'Imana',
      language: 'Kinyarwanda',
      coverGradient: [Color(0xFF065F46), Color(0xFF10B981)],
      abbrev: 'II',
      imagePath: 'assets/bible/logos/bibiriya_ijambo_ryimana_kinyarwanda.png',
    ),
    BibleVersion(
      id: 'KJV',
      name: 'King James Version',
      language: 'English',
      coverGradient: [Color(0xFF78350F), Color(0xFFD97706)],
      abbrev: 'KJV',
      imagePath: 'assets/bible/logos/holy_bible_english_kjv.png',
    ),
    BibleVersion(
      id: 'GNB',
      name: 'Good News Bible',
      language: 'English',
      coverGradient: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
      abbrev: 'GNB',
      imagePath: 'assets/bible/logos/Holy_bible_good_news_english.png',
    ),
  ];

  static const List<BibleVersion> catholicBibles = [
    BibleVersion(
      id: 'BN',
      name: 'Bibiliya Ntagatifu',
      language: 'Kinyarwanda',
      coverGradient: [Color(0xFF991B1B), Color(0xFFEF4444)],
      abbrev: 'BN',
      imagePath: 'assets/bible/logos/bibiriya_ntagatifu_kinyarwanda.png',
    ),
    BibleVersion(
      id: 'IID',
      name: 'Ijambo ry\'Imana d',
      language: 'Kinyarwanda',
      coverGradient: [Color(0xFF374151), Color(0xFF6B7280)],
      abbrev: 'IID',
      imagePath: 'assets/bible/logos/bibiriya_ijambo_ryimana_d_kinyarwanda.png',
    ),
    BibleVersion(
      id: 'CE',
      name: 'Catholic Public Domain',
      language: 'English',
      coverGradient: [Color(0xFF854D0E), Color(0xFFEAB308)],
      abbrev: 'CE',
      imagePath: 'assets/bible/logos/Holy_bible_catholic_english.png',
    ),
    BibleVersion(
      id: 'GNC',
      name: 'Good News Catholic',
      language: 'English',
      coverGradient: [Color(0xFF0F766E), Color(0xFF14B8A6)],
      abbrev: 'GNC',
      imagePath: 'assets/bible/logos/Holy_bible_good_news_catholic_english.png',
    ),
  ];

  Future<void> _selectBible(BuildContext context, BibleVersion version) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnglish = version.language == 'English';

    if (isEnglish) {
      activeEnglishBibleNotifier.value = version.id;
      await prefs.setString('active_english_bible', version.id);
      bibleTranslationNotifier.value = 'english';
      await prefs.setString('bible_translation_mode', 'english');
    } else {
      activeKinyarwandaBibleNotifier.value = version.id;
      await prefs.setString('active_kinyarwanda_bible', version.id);
      bibleTranslationNotifier.value = 'kinyarwanda';
      await prefs.setString('bible_translation_mode', 'kinyarwanda');
    }

    // Cache the active selected Bible ID so the screen state knows a Bible has been picked
    await prefs.setString('active_bible_id', version.id);
    onBibleSelected();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          localeNotifier.value == 'en' ? 'Select Bible' : 'Hitamo Bibiliya',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              localeNotifier.value == 'en' ? 'Protestant' : 'Abarokore',
            ),
            const SizedBox(height: 12),
            _buildBiblesGrid(context, protestantBibles),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              localeNotifier.value == 'en' ? 'Catholic' : 'Abakatolike',
            ),
            const SizedBox(height: 12),
            _buildBiblesGrid(context, catholicBibles),
            const SizedBox(height: 80), // extra padding for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildBiblesGrid(BuildContext context, List<BibleVersion> bibles) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bibles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemBuilder: (context, index) {
        final bible = bibles[index];
        return _buildBibleCard(context, bible);
      },
    );
  }

  Widget _buildBibleCard(BuildContext context, BibleVersion bible) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => _selectBible(context, bible),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      bible.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback UI if image fails to load
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: bible.coverGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 8,
                                child: Container(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.book,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      bible.abbrev,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                bible.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                bible.language,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

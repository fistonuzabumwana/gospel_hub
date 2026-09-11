import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_localizations.dart';
import '../../main.dart';

class ReaderSettingsModal {
  static void show(
    BuildContext context, {
    required double fontSize,
    required ValueChanged<double> onFontSizeChanged,
    required String customThemeMode,
    required ValueChanged<String> onCustomThemeModeChanged,
    required String activeThemeMode,
    required String translationMode,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.translate('reader_settings_font_size'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          min: 12.0,
                          max: 30.0,
                          value: fontSize,
                          onChanged: (val) {
                            fontSize = val;
                            setModalState(() {});
                            onFontSizeChanged(val);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 24),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.translate('reader_settings_theme'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_white'),
                        selected: activeThemeMode == 'Light',
                        bgColor: Colors.white,
                        textColor: Colors.black87,
                        onTap: () {
                          activeThemeMode = 'Light';
                          setModalState(() {});
                          onCustomThemeModeChanged('Light');
                        },
                      ),
                      ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_warm'),
                        selected: activeThemeMode == 'Warm',
                        bgColor: const Color(0xFFF7F2E8),
                        textColor: const Color(0xFF4C3E26),
                        onTap: () {
                          activeThemeMode = 'Warm';
                          setModalState(() {});
                          onCustomThemeModeChanged('Warm');
                        },
                      ),
                      ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_black'),
                        selected: activeThemeMode == 'Dark',
                        bgColor: const Color(0xFF1B1D1B),
                        textColor: Colors.white70,
                        onTap: () {
                          activeThemeMode = 'Dark';
                          setModalState(() {});
                          onCustomThemeModeChanged('Dark');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.translate('reader_settings_translation'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       TranslationOptionButton(
                        label: 'Kinyarwanda',
                        selected: translationMode == 'kinyarwanda',
                        onTap: () async {
                          bibleTranslationNotifier.value = 'kinyarwanda';
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('bible_translation_mode', 'kinyarwanda');
                          translationMode = 'kinyarwanda';
                          setModalState(() {});
                        },
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: activeEnglishBibleNotifier,
                        builder: (context, activeEng, _) {
                          String engLabel = 'English KJV';
                          if (activeEng == 'GNB') {
                            engLabel = 'English GNB';
                          } else if (activeEng == 'CE') {
                            engLabel = 'English CPDV';
                          } else if (activeEng == 'GNC') {
                            engLabel = 'English GNC';
                          }
                          return TranslationOptionButton(
                            label: engLabel,
                            selected: translationMode == 'english',
                            onTap: () async {
                              bibleTranslationNotifier.value = 'english';
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('bible_translation_mode', 'english');
                              translationMode = 'english';
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                      TranslationOptionButton(
                        label: 'Parallel',
                        selected: translationMode == 'parallel',
                        onTap: () async {
                          bibleTranslationNotifier.value = 'parallel';
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('bible_translation_mode', 'parallel');
                          translationMode = 'parallel';
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ThemeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const ThemeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        side: BorderSide(
          color: selected ? primaryColor : Colors.grey.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class TranslationOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TranslationOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
        backgroundColor: selected ? theme.primaryColor : Colors.transparent,
        side: BorderSide(color: selected ? theme.primaryColor : Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/widget_service.dart';
import '../services/app_localizations.dart';

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  double _opacity = 1.0;
  double _fontSize = 14.5;
  String _fontStyle = 'serif';
  String _widgetLanguage = 'rw';
  String _previewRef = '';
  String _previewText = '';
  bool _isInitialLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        WidgetService.getWidgetOpacity(),
        WidgetService.getWidgetFontSize(),
        WidgetService.getWidgetFontStyle(),
        WidgetService.getWidgetLanguage(),
      ]);
      final lang = results[3] as String;
      final preview = await WidgetService.getVerseOfDayPreview(lang);
      if (!mounted) return;
      setState(() {
        _opacity = results[0] as double;
        _fontSize = results[1] as double;
        _fontStyle = results[2] as String;
        _widgetLanguage = lang;
        _previewRef = preview['ref'] ?? '';
        _previewText = preview['text'] ?? '';
      });
    } catch (_) {
      // Defaults above are enough to show the screen.
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final opacity = _opacity.clamp(WidgetService.minWidgetOpacity, WidgetService.maxWidgetOpacity);
      await WidgetService.applyWidgetSettings(
        opacity: opacity,
        fontSize: _fontSize,
        fontStyle: _fontStyle,
        language: _widgetLanguage,
      );
      if (!mounted) return;
      final isRw = AppLocalizations.translate('settings_title') == 'Iparametre';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRw ? 'Uburyo bwakagaruwe buhindutse!' : 'Widget settings applied!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _refreshPreviewForLanguage(String lang) async {
    final preview = await WidgetService.getVerseOfDayPreview(lang);
    if (!mounted) return;
    setState(() {
      _widgetLanguage = lang;
      _previewRef = preview['ref'] ?? '';
      _previewText = preview['text'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isRw = AppLocalizations.translate('settings_title') == 'Iparametre';

    final previewRef = _previewRef.isNotEmpty
        ? _previewRef
        : (isRw ? 'Yohana 3:16' : 'John 3:16');
    final previewText = _previewText.isNotEmpty
        ? _previewText
        : (isRw
            ? 'Kuko Imana yakunze abari mu isi cyane, ikabasaba Umwana wayo w\'ikinege ngo umwizera wese atarimbuka, ahubwo ahabwe ubugingo buhoraho.'
            : 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.');

    TextStyle previewTextStyle;
    if (_fontStyle == 'sans') {
      previewTextStyle = TextStyle(
        fontFamily: 'sans-serif',
        fontSize: _fontSize,
        color: Colors.white.withValues(alpha: 0.9),
        height: 1.3,
      );
    } else if (_fontStyle == 'mono') {
      previewTextStyle = TextStyle(
        fontFamily: 'monospace',
        fontSize: _fontSize,
        color: Colors.white.withValues(alpha: 0.9),
        height: 1.3,
      );
    } else {
      previewTextStyle = TextStyle(
        fontFamily: 'serif',
        fontSize: _fontSize,
        color: Colors.white.withValues(alpha: 0.9),
        height: 1.3,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRw ? 'Iparametre z\'Akamenyetso' : 'Widget Settings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: isRw ? 'Bika' : 'Save',
            onPressed: (_isInitialLoading || _isSaving) ? null : _saveSettings,
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ── PREVIEW HEADER ──
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    (isRw ? 'Uko Akamenyetso Kagaragara' : 'Live Widget Preview').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // ── WIDGET PREVIEW BOARD ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF334155),
                              const Color(0xFF0F172A),
                              const Color(0xFF475569),
                            ]
                          : [
                              const Color(0xFFE2E8F0),
                              const Color(0xFFF8FAFC),
                              const Color(0xFFCBD5E1),
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C1A).withValues(alpha: _opacity),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/logo/Gospel hub logo.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                previewRef,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_left,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          previewText,
                          style: previewTextStyle,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── OPACITY CONTROLLER CARD ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isRw ? 'Urumuri rw\'inyuma (Opacity)' : 'Background Opacity',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            Text(
                              '${(_opacity * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _opacity,
                          min: WidgetService.minWidgetOpacity,
                          max: WidgetService.maxWidgetOpacity,
                          divisions: 9,
                          label: '${(_opacity * 100).round()}%',
                          activeColor: primaryColor,
                          inactiveColor: primaryColor.withValues(alpha: 0.2),
                          onChanged: (val) {
                            setState(() => _opacity = val);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '10%',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            Text(
                              '100%',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── BIBLE LANGUAGE ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRw ? 'Ururimi rw\'Ijambo' : 'Bible Translation',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRw
                              ? 'Hitamo ururimi rw\'akamenyetso (ntibihuye n\'ururimi rw\'app).'
                              : 'Language shown on the home screen widget (separate from app UI).',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Ikinyarwanda')),
                                selected: _widgetLanguage == 'rw',
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) _refreshPreviewForLanguage('rw');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('English')),
                                selected: _widgetLanguage == 'en',
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) _refreshPreviewForLanguage('en');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── FONT SIZE CONTROLLER CARD ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isRw ? 'Ingano y\'inyuguti' : 'Font Size',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            Text(
                              '${_fontSize.toStringAsFixed(1)} sp',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _fontSize,
                          min: 12.0,
                          max: 20.0,
                          divisions: 16,
                          activeColor: primaryColor,
                          inactiveColor: primaryColor.withValues(alpha: 0.2),
                          onChanged: (val) {
                            setState(() => _fontSize = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── FONT STYLE CONTROLLER CARD ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRw ? 'Ubwoko bw\'Inyuguti' : 'Font Style',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Serif')),
                                selected: _fontStyle == 'serif',
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _fontStyle = 'serif');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Sans-Serif')),
                                selected: _fontStyle == 'sans',
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _fontStyle = 'sans');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Monospace')),
                                selected: _fontStyle == 'mono',
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _fontStyle = 'mono');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── APPLY BUTTON ──
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_isInitialLoading || _isSaving) ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    isRw ? 'Bika Ibiheruka' : 'Save & Apply to Widget',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
                if (_isSaving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x44000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }
}

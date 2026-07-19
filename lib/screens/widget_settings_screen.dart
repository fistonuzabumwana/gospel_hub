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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final opacity = await WidgetService.getWidgetOpacity();
    final size = await WidgetService.getWidgetFontSize();
    final style = await WidgetService.getWidgetFontStyle();

    if (mounted) {
      setState(() {
        _opacity = opacity;
        _fontSize = size;
        _fontStyle = style;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await WidgetService.setWidgetOpacity(_opacity);
    await WidgetService.setWidgetFontSize(_fontSize);
    await WidgetService.setWidgetFontStyle(_fontStyle);
    setState(() => _isLoading = false);

    if (mounted) {
      final isRw = AppLocalizations.translate('settings_title') == 'Iparametre';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRw ? 'Uburyo bwakagaruwe buhindutse!' : 'Widget settings applied!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isRw = AppLocalizations.translate('settings_title') == 'Iparametre';

    final previewRef = isRw ? 'Yohana 3:16' : 'John 3:16';
    final previewText = isRw
        ? 'Kuko Imana yakunze abari mu isi cyane, ikabasaba Umwana wayo w\'ikinege ngo umwizera wese atarimbuka, ahubwo ahabwe ubugingo buhoraho.'
        : 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.';

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
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                    // Grid background to show opacity adjustments
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 120),
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
                          const SizedBox(height: 12),
                          Text(
                            previewText,
                            style: previewTextStyle,
                          ),
                        ],
                      ),
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
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          activeColor: primaryColor,
                          inactiveColor: primaryColor.withValues(alpha: 0.2),
                          onChanged: (val) {
                            setState(() => _opacity = val);
                          },
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
                  onPressed: _isLoading ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    isRw ? 'Bika Ibiheruka' : 'Save & Apply to Widget',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

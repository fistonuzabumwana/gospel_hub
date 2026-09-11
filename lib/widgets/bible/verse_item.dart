import 'package:flutter/material.dart';
import '../../models/bible_verse.dart';

class VerseItem extends StatefulWidget {
  final BibleVerse verse;
  final double fontSize;
  final Color textColor;
  final Color primaryColor;
  final bool isHighlighted;
  final Color? highlightColor;
  final bool hasNote;
  final String? englishText;
  final String translationMode;
  final List<String>? tags;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTtsActive;
  final int? ttsStartChar;
  final int? ttsEndChar;
  final bool isSelected;
  /// When set (usually on the first verse), shows a large chapter drop-cap
  /// instead of the small verse number.
  final int? chapterDropCap;
  /// Hide the small verse number (used when a shared chapter drop-cap is shown
  /// beside several short opening verses).
  final bool hideVerseNumber;
  final bool isDark;

  const VerseItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.textColor,
    required this.primaryColor,
    required this.isHighlighted,
    this.highlightColor,
    required this.hasNote,
    this.englishText,
    required this.translationMode,
    this.tags,
    required this.onTap,
    this.onLongPress,
    this.isTtsActive = false,
    this.ttsStartChar,
    this.ttsEndChar,
    this.isSelected = false,
    this.chapterDropCap,
    this.hideVerseNumber = false,
    required this.isDark,
  });

  @override
  State<VerseItem> createState() => _VerseItemState();
}

class _VerseItemState extends State<VerseItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  @override
  void didUpdateWidget(VerseItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  void _startHighlightAnimation() {
    _controller.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.stop();
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<InlineSpan> _buildSpans(
    String fullText,
    bool isTtsActive,
    int? start,
    int? end,
    TextStyle style,
    Color primaryColor, {
    int textOffset = 0,
  }) {
    final localStart = start == null ? null : start - textOffset;
    final localEnd = end == null ? null : end - textOffset;
    if (!isTtsActive ||
        localStart == null ||
        localEnd == null ||
        localStart < 0 ||
        localEnd > fullText.length ||
        localStart >= localEnd) {
      return [TextSpan(text: fullText, style: style)];
    }

    final prefix = fullText.substring(0, localStart);
    final word = fullText.substring(localStart, localEnd);
    final suffix = fullText.substring(localEnd);

    return [
      TextSpan(text: prefix, style: style),
      TextSpan(
        text: word,
        style: style.copyWith(
          backgroundColor: primaryColor.withValues(alpha: 0.25),
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
      TextSpan(text: suffix, style: style),
    ];
  }

  /// Splits [text] so the first lines sit beside [dropCapSize], rest wrap below.
  /// Returns (beside, below, belowStartOffsetInOriginal).
  (String, String, int) _splitForDropCap({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required Size dropCapSize,
    required double gap,
  }) {
    final sideWidth = (maxWidth - dropCapSize.width - gap).clamp(40.0, maxWidth);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: sideWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return (text, '', 0);

    final lineHeight = metrics.first.height;
    final linesBeside =
        (dropCapSize.height / lineHeight).ceil().clamp(1, metrics.length);

    var y = 0.0;
    for (var i = 0; i < linesBeside; i++) {
      y += metrics[i].height;
    }

    final pos = painter.getPositionForOffset(Offset(sideWidth, y - 0.5));
    var split = pos.offset.clamp(0, text.length);

    // Prefer splitting on a space so we don't break mid-word awkwardly.
    if (split > 0 && split < text.length && text[split - 1] != ' ') {
      final space = text.lastIndexOf(' ', split);
      if (space > 0) split = space + 1;
    }

    final beside = text.substring(0, split).trimRight();
    final belowRaw = text.substring(split);
    final below = belowRaw.trimLeft();
    final belowOffset = split + (belowRaw.length - below.length);
    return (beside, below, belowOffset);
  }

  Widget _buildDropCapVerse({
    required String text,
    required TextStyle bodyStyle,
    required Color accentBlue,
    required bool isDark,
  }) {
    final dropCapStyle = TextStyle(
      fontSize: widget.fontSize * 5.2,
      fontWeight: FontWeight.w500,
      height: 0.88,
      fontFamily: 'serif',
      color: widget.textColor,
      letterSpacing: -2.0,
    );
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dropPainter = TextPainter(
          text: TextSpan(text: '${widget.chapterDropCap}', style: dropCapStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dropSize = dropPainter.size;

        final split = _splitForDropCap(
          text: text,
          style: bodyStyle,
          maxWidth: constraints.maxWidth,
          dropCapSize: dropSize,
          gap: gap,
        );
        final beside = split.$1;
        final below = split.$2;
        final belowOffset = split.$3;
        final showParallel = widget.translationMode == 'parallel' &&
            widget.englishText != null &&
            widget.englishText!.isNotEmpty;
        final englishStyle = TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: widget.fontSize - 1.5,
          height: 1.35,
          color: isDark ? Colors.white60 : Colors.black54,
        );
        // Keep English with this verse: beside the drop-cap when the
        // primary text fully fits there; otherwise under the wrapped text.
        final englishBesidePrimary = showParallel && below.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: gap, top: 0),
                  child: Text('${widget.chapterDropCap}', style: dropCapStyle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: _buildSpans(
                            beside,
                            widget.isTtsActive,
                            widget.ttsStartChar,
                            widget.ttsEndChar,
                            bodyStyle,
                            accentBlue,
                          ),
                        ),
                      ),
                      if (englishBesidePrimary) ...[
                        const SizedBox(height: 4),
                        Text(widget.englishText!, style: englishStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (below.isNotEmpty)
              RichText(
                text: TextSpan(
                  children: _buildSpans(
                    below,
                    widget.isTtsActive,
                    widget.ttsStartChar,
                    widget.ttsEndChar,
                    bodyStyle,
                    accentBlue,
                    textOffset: belowOffset,
                  ),
                ),
              ),
            if (showParallel && !englishBesidePrimary) ...[
              const SizedBox(height: 4),
              Text(widget.englishText!, style: englishStyle),
            ],
            if (widget.hasNote ||
                (widget.tags != null && widget.tags!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.hasNote)
                      Icon(
                        Icons.edit_note,
                        size: widget.fontSize + 2,
                        color: accentBlue,
                      ),
                    if (widget.tags != null)
                      ...widget.tags!.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentBlue,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accentBlue = isDark ? const Color(0xFF60A5FA) : widget.primaryColor;
    
    // Determine persistent highlight background color
    Color containerColor = Colors.transparent;
    if (widget.highlightColor != null) {
      containerColor = widget.highlightColor!.withValues(alpha: isDark ? 0.20 : 0.35);
    }

    final bodyStyle = TextStyle(
      fontSize: widget.fontSize,
      color: widget.textColor,
      height: 1.35,
      fontFamily: 'serif',
    );
    final mainText = widget.translationMode == 'english'
        ? (widget.englishText ?? widget.verse.text)
        : widget.verse.text;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? accentBlue.withValues(alpha: isDark ? 0.25 : 0.15)
                : (widget.isHighlighted 
                    ? accentBlue.withValues(alpha: _animation.value)
                    : containerColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? accentBlue : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 8.0),
          child: child,
        );
      },
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.0),
          child: widget.chapterDropCap != null
              ? _buildDropCapVerse(
                  text: mainText,
                  bodyStyle: bodyStyle,
                  accentBlue: accentBlue,
                  isDark: isDark,
                )
              : RichText(
                  text: TextSpan(
                    style: bodyStyle,
                    children: [
                      if (!widget.hideVerseNumber)
                        TextSpan(
                          text: '${widget.verse.verse}  ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: accentBlue,
                            fontSize: widget.fontSize - 1,
                          ),
                        ),
                      ..._buildSpans(
                        mainText,
                        widget.isTtsActive,
                        widget.ttsStartChar,
                        widget.ttsEndChar,
                        bodyStyle,
                        accentBlue,
                      ),
                      if (widget.translationMode == 'parallel' &&
                          widget.englishText != null) ...[
                        const TextSpan(text: '\n'),
                        TextSpan(
                          text: widget.englishText!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: widget.fontSize - 1.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                      if (widget.hasNote)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Icon(
                              Icons.edit_note,
                              size: widget.fontSize + 2,
                              color: accentBlue,
                            ),
                          ),
                        ),
                      if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                        const TextSpan(text: '\n'),
                        WidgetSpan(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Wrap(
                              spacing: 4.0,
                              runSpacing: 2.0,
                              children: widget.tags!.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: accentBlue,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

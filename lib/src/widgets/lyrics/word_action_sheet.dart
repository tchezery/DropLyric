import '../../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../core/services/dictionary_service.dart';

/// Modal de ações ao pressionar uma palavra da letra:
/// - Ícone de Livrinho (📖 Dicionário) para ver significado completo, fonética e tradução.
/// - Botão para alternar status no vocabulário (Conhecida / Estudo).
/// - Botão para copiar a palavra.
class WordActionSheet extends StatefulWidget {
  final String rawWord;
  final String normalized;
  final String? sentence;
  final bool isInitiallyKnown;
  final String sourceLanguage;
  final String targetLanguage;
  final Future<void> Function() onToggleWord;

  const WordActionSheet({
    super.key,
    required this.rawWord,
    required this.normalized,
    this.sentence,
    required this.isInitiallyKnown,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onToggleWord,
  });

  static Future<void> show(
    BuildContext context, {
    required String rawWord,
    required String normalized,
    String? sentence,
    required bool isInitiallyKnown,
    required String sourceLanguage,
    required String targetLanguage,
    required Future<void> Function() onToggleWord,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WordActionSheet(
        rawWord: rawWord,
        normalized: normalized,
        sentence: sentence,
        isInitiallyKnown: isInitiallyKnown,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        onToggleWord: onToggleWord,
      ),
    );
  }

  @override
  State<WordActionSheet> createState() => _WordActionSheetState();
}

class _WordActionSheetState extends State<WordActionSheet> {
  final DictionaryService _dictionaryService = DictionaryService();

  late bool _isKnown;
  bool _loading = true;
  WordDefinition? _definition;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isKnown = widget.isInitiallyKnown;
    _lookup();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dictionaryService.lookupWord(
        widget.normalized,
        sentence: widget.sentence,
        sourceLang: widget.sourceLanguage,
        targetLang: widget.targetLanguage,
      );
      if (mounted) {
        setState(() {
          _definition = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = "Could not load the definition at this time.";
        });
      }
    }
  }

  int _saveVersion = 0;
  bool? _savedKnown;

  Future<void> _handleToggle() async {
    _savedKnown ??= _isKnown;
    final version = ++_saveVersion;
    final desired = !_isKnown;
    HapticFeedback.mediumImpact();
    setState(() => _isKnown = desired);
    try {
      await widget.onToggleWord();
      _savedKnown = desired;
    } catch (_) {
      if (mounted) {
        if (version == _saveVersion) {
          setState(() => _isKnown = _savedKnown!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, "Could not save the word. Try again."))),
        );
      }
    }
  }

  void _copyToClipboard() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.rawWord));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Localizations.localeOf(context).languageCode == 'pt' ? 'Palavra "${widget.rawWord}" copiada!' : 'Word "${widget.rawWord}" copied!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : AppTheme.white;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final primaryTextColor = isDark ? AppTheme.labelDark : AppTheme.labelLight;
    final secondaryTextColor = isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.80,
        maxWidth: 640,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // iOS drag indicator
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Word Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rawWord,
                          style: TextStyle(
                            fontFamily: '.SF Pro Display',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _isKnown
                                    ? AppTheme.spotifyGreen.withValues(alpha: 0.15)
                                    : AppTheme.appleBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isKnown
                                    ? (isPortuguese ? 'CONHECIDA' : 'KNOWN')
                                    : (isPortuguese ? 'ESTUDANDO' : 'LEARNING'),
                                style: TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _isKnown
                                      ? AppTheme.spotifyGreen
                                      : AppTheme.appleBlue,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.sourceLanguage.toUpperCase(),
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 12,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 1. Toggle Vocabulary Status Button
                  Expanded(
                    flex: 4,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _handleToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _isKnown
                              ? AppTheme.spotifyGreen
                              : AppTheme.appleBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isKnown
                                  ? CupertinoIcons.checkmark_alt
                                  : CupertinoIcons.bookmark_fill,
                              size: 16,
                              color: AppTheme.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isKnown
                                  ? (isPortuguese ? 'Conhecida' : 'Known')
                                  : (isPortuguese ? 'Marcar como conhecida' : 'Mark as known'),
                              style: const TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. Copy Button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _copyToClipboard,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        CupertinoIcons.doc_on_clipboard,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
              height: 1,
            ),

            // Dictionary content area
            Expanded(child: _buildDictionaryBody(cardColor, primaryTextColor, secondaryTextColor, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildDictionaryBody(Color cardColor, Color primaryTextColor, Color secondaryTextColor, bool isDark) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 12),
              const SizedBox(height: 14),
              Text(
                tr(context, "Searching for meaning in dictionary..."),
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.wifi_slash,
                size: 36,
                color: secondaryTextColor,
              ),
              const SizedBox(height: 12),
              Text(
                tr(context, _errorMessage!),
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                onPressed: _lookup,
                child: Text(
                  tr(context, "Try again"),
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.appleBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final def = _definition;
    if (def == null ||
        (def.meanings.isEmpty &&
            def.translation == null &&
            def.sentenceTranslation == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.book, size: 40, color: secondaryTextColor),
              const SizedBox(height: 12),
              Text(
                Localizations.localeOf(context).languageCode == 'pt'
                    ? 'Nenhum significado encontrado\npara "${widget.rawWord}".'
                    : 'No detailed meaning found\nfor "${widget.rawWord}".',
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Phonetic pronunciation
        if (def.phonetic != null && def.phonetic!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.volume_up,
                  size: 16,
                  color: secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Text(
                  def.phonetic!,
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

        // 1. Literal Word Translation Card
        if (def.translation != null && def.translation!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.textformat_abc,
                      size: 16,
                      color: AppTheme.appleBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, "LITERAL TRANSLATION"),
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.appleBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  def.translation!,
                  style: TextStyle(
                    fontFamily: '.SF Pro Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
          ),

        // 2. Full Sentence Translation Card
        if (def.sentenceTranslation != null &&
            def.sentenceTranslation!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.text_quote,
                      size: 16,
                      color: AppTheme.spotifyGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, "FULL SENTENCE"),
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.spotifyGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  def.sentenceTranslation!,
                  style: TextStyle(
                    fontFamily: '.SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                    height: 1.35,
                  ),
                ),
                if (def.sentenceText != null &&
                    def.sentenceText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${def.sentenceText!}”',
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Definitions list
        if (def.meanings.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              tr(context, "DICTIONARY DEFINITIONS"),
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...def.meanings.map((meaning) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meaning.partOfSpeech.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tr(context, meaning.partOfSpeech.toLowerCase()),
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  Text(
                    meaning.definition,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 14,
                      height: 1.4,
                      color: primaryTextColor,
                    ),
                  ),
                  if (meaning.example != null && meaning.example!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“${meaning.example}”',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

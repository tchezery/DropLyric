import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../core/services/quiz_service.dart';

/// Modal bottom-sheet exibido ao final da música ou ao sair do Player,
/// permitindo ao usuário fixar as palavras marcadas através de minigames:
/// 1) Completar a frase da música que acabou de ouvir
/// 2) Tradução por digitação ou múltipla escolha
class VocabularyQuizSheet extends StatefulWidget {
  final List<String> words;
  final String? trackTitle;
  final String? artistName;
  final String language;

  const VocabularyQuizSheet({
    super.key,
    required this.words,
    this.trackTitle,
    this.artistName,
    this.language = 'en',
  });

  static Future<bool> show(
    BuildContext context, {
    required List<String> words,
    String? trackTitle,
    String? artistName,
    String language = 'en',
  }) async {
    if (words.isEmpty) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => VocabularyQuizSheet(
        words: words,
        trackTitle: trackTitle,
        artistName: artistName,
        language: language,
      ),
    );
    return result ?? true;
  }

  @override
  State<VocabularyQuizSheet> createState() => _VocabularyQuizSheetState();
}

class _VocabularyQuizSheetState extends State<VocabularyQuizSheet> {
  final QuizService _quizService = QuizService.instance;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Random _rng = Random();

  int _currentIndex = 0;
  bool _loading = true;
  QuizQuestion? _currentQuestion;
  LyricFillQuestion? _currentLyricQuestion;

  String? _selectedOption;
  bool? _isCorrect;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadQuestionForIndex(_currentIndex);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionForIndex(int index) async {
    if (index >= widget.words.length) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _selectedOption = null;
        _isCorrect = null;
        _submitted = false;
        _currentQuestion = null;
        _currentLyricQuestion = null;
        _textController.clear();
      });
    }

    final rawWord = widget.words[index];

    // Se temos a música da sessão, tenta gerar desafio de completar a frase daquela música
    if (widget.trackTitle != null && widget.artistName != null && ((index % 2 == 1) || _rng.nextDouble() > 0.45)) {
      final lyricQ = await _quizService.generateLyricFillQuestion(
        trackTitle: widget.trackTitle,
        artistName: widget.artistName,
        targetWords: [rawWord],
      );

      if (!mounted) return;

      if (lyricQ != null) {
        setState(() {
          _currentLyricQuestion = lyricQ;
          _loading = false;
        });
        return;
      }
    }

    // Modo Tradução (Múltipla escolha ou digitação)
    final data = await _quizService.fetchTranslationData(
      rawWord,
      sourceLang: widget.language,
      targetLang: 'pt',
    );

    if (!mounted) return;

    if (data != null) {
      final isTyping = (index % 2 == 1) || (_rng.nextDouble() > 0.6);
      final question = _quizService.generateQuestion(
        data: data,
        trackName: widget.trackTitle,
        artistName: widget.artistName,
        forceTyping: isTyping,
        forceMultipleChoice: !isTyping,
      );
      setState(() {
        _currentQuestion = question;
        _loading = false;
      });
    } else {
      _onNextWord();
    }
  }

  void _onSelectOption(String option) {
    if (_submitted || _currentQuestion == null) return;

    final correct = _currentQuestion!.checkAnswer(option);
    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _selectedOption = option;
      _isCorrect = correct;
      _submitted = true;
    });
  }

  void _onSubmitText() {
    final text = _textController.text.trim();
    if (text.isEmpty || _submitted) return;

    _focusNode.unfocus();
    bool correct = false;
    if (_currentLyricQuestion != null) {
      correct = _currentLyricQuestion!.checkAnswer(text);
    } else if (_currentQuestion != null) {
      correct = _currentQuestion!.checkAnswer(text);
    }

    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isCorrect = correct;
      _submitted = true;
    });
  }

  void _onNextWord() {
    if (_currentIndex + 1 < widget.words.length) {
      setState(() => _currentIndex++);
      _loadQuestionForIndex(_currentIndex);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  String _t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final isLyricGame = _currentLyricQuestion != null;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuad,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header bar: Badge / Progress & Skip button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLyricGame
                          ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                          : AppTheme.spotifyGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLyricGame ? CupertinoIcons.music_mic : CupertinoIcons.sparkles,
                          size: 13,
                          color: isLyricGame ? const Color(0xFF007AFF) : AppTheme.spotifyGreen,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLyricGame
                              ? '${_currentIndex + 1}/${widget.words.length} • ${_t('COMPLETAR A MÚSICA', 'COMPLETE THE LYRIC')}'
                              : '${_currentIndex + 1}/${widget.words.length} • ${_t('FIXAR VOCABULÁRIO', 'MEMORIZE WORD')}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: isLyricGame ? const Color(0xFF007AFF) : AppTheme.spotifyGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      _t('Pular', 'Skip'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading) ...[
                const SizedBox(height: 40),
                CupertinoActivityIndicator(radius: 14, color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  _t('Preparando desafio...', 'Preparing challenge...'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
              ] else if (_currentLyricQuestion != null) ...[
                // JOGO: COMPLETAR A FRASE DA MÚSICA
                _buildLyricGameContent(colors, isDark),
              ] else if (_currentQuestion != null) ...[
                // JOGO: VOCABULÁRIO TRADICIONAL
                _buildVocabGameContent(colors, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricGameContent(ColorScheme colors, bool isDark) {
    final q = _currentLyricQuestion!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.trackTitle != null && widget.trackTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _t(
                'Complete a frase da música que você estava ouvindo:',
                'Complete the line from the song you were listening to:',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 13,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Frase da música com lacuna
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
              width: 1,
            ),
          ),
          child: Text(
            '"${q.lineWithBlank}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
              color: colors.onSurface,
            ),
          ),
        ),

        if (q.wordTranslation != null && q.wordTranslation!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _t('Dica de tradução: "${q.wordTranslation}"', 'Translation hint: "${q.wordTranslation}"'),
              style: const TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 13,
                color: Color(0xFFFF9500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Input para digitar a palavra
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onSubmitText(),
                placeholder: _t('Digite a palavra que falta...', 'Type the missing word...'),
                placeholderStyle: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 15,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 16,
                  color: colors.onSurface,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _submitted ? null : _onSubmitText,
              child: Text(
                _t('Verificar', 'Check'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        // Resultado
        if (_submitted) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isCorrect == true
                  ? AppTheme.spotifyGreen.withValues(alpha: 0.12)
                  : Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isCorrect == true
                    ? AppTheme.spotifyGreen.withValues(alpha: 0.3)
                    : Colors.orangeAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCorrect == true
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.exclamationmark_circle_fill,
                      color: _isCorrect == true ? AppTheme.spotifyGreen : Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCorrect == true
                          ? _t('Acertou em cheio! 🎉', 'Spot on! 🎉')
                          : _t('A palavra era: "${q.targetWord}"', 'The word was: "${q.targetWord}"'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _t('Frase completa: "${q.fullLine}"', 'Full line: "${q.fullLine}"'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildActionButton(),
        ],
      ],
    );
  }

  Widget _buildVocabGameContent(ColorScheme colors, bool isDark) {
    final q = _currentQuestion!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.trackTitle != null && widget.trackTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _t(
                'Você marcou esta palavra ouvindo "${widget.trackTitle}":',
                'You marked this word while listening to "${widget.trackTitle}":',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 13,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Palavra principal
        Text(
          q.word,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontSF,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          q.isTypingMode
              ? _t('Escreva uma tradução ou significado em português:', 'Type a translation or meaning:')
              : _t('Selecione uma das traduções corretas:', 'Select one of the correct translations:'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontSF,
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        if (q.isTypingMode) ...[
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onSubmitText(),
                  placeholder: _t('Ex: gostar, como, ...', 'Type here...'),
                  placeholderStyle: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 15,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 16,
                    color: colors.onSurface,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.spotifyGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _submitted ? null : _onSubmitText,
                child: Text(
                  _t('Verificar', 'Check'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Column(
            children: q.options.map((option) {
              final isSelected = _selectedOption == option;
              final isOptionCorrect = q.checkAnswer(option);

              Color bg = isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000);
              Color border = isDark ? const Color(0x26FFFFFF) : const Color(0x14000000);
              Color textColor = colors.onSurface;

              if (_submitted) {
                if (isOptionCorrect) {
                  bg = AppTheme.spotifyGreen.withValues(alpha: 0.18);
                  border = AppTheme.spotifyGreen;
                  textColor = AppTheme.spotifyGreen;
                } else if (isSelected && !isOptionCorrect) {
                  bg = Colors.redAccent.withValues(alpha: 0.15);
                  border = Colors.redAccent;
                  textColor = Colors.redAccent;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitted ? null : () => _onSelectOption(option),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 16,
                                fontWeight: isSelected || (_submitted && isOptionCorrect)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (_submitted && isOptionCorrect)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              size: 20,
                              color: AppTheme.spotifyGreen,
                            )
                          else if (isSelected && !isOptionCorrect)
                            const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        if (_submitted) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isCorrect == true
                  ? AppTheme.spotifyGreen.withValues(alpha: 0.12)
                  : Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isCorrect == true
                    ? AppTheme.spotifyGreen.withValues(alpha: 0.3)
                    : Colors.orangeAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCorrect == true
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.exclamationmark_circle_fill,
                      color: _isCorrect == true ? AppTheme.spotifyGreen : Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCorrect == true
                          ? _t('Mandou muito bem! 🎉', 'Well done! 🎉')
                          : _t('Quase lá!', 'Almost there!'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  q.allAcceptedTranslations.length > 1
                      ? _t(
                          'Significados aceitos: ${q.allAcceptedTranslations.take(5).join(", ")}',
                          'Accepted meanings: ${q.allAcceptedTranslations.take(5).join(", ")}',
                        )
                      : _t(
                          'Tradução: ${q.correctAnswer}',
                          'Translation: ${q.correctAnswer}',
                        ),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildActionButton(),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.spotifyGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _onNextWord,
        child: Text(
          _currentIndex + 1 < widget.words.length
              ? _t('Próxima palavra', 'Next word')
              : _t('Concluir', 'Done'),
          style: const TextStyle(
            fontFamily: AppTheme.fontSF,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

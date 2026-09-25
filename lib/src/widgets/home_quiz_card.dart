import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../core/models/known_word_model.dart';
import '../core/services/quiz_service.dart';

enum HomeQuizMode {
  vocabulary,
  lyricFill,
}

class HomeQuizCard extends StatefulWidget {
  final List<KnownWordModel> words;
  final VoidCallback? onDismissed;
  final HomeQuizMode? initialMode;
  final bool lockMode;

  const HomeQuizCard({
    super.key,
    required this.words,
    this.onDismissed,
    this.initialMode,
    this.lockMode = false,
  });

  @override
  State<HomeQuizCard> createState() => _HomeQuizCardState();
}

class _HomeQuizCardState extends State<HomeQuizCard> {
  final QuizService _quizService = QuizService.instance;
  final TextEditingController _lyricController = TextEditingController();
  final FocusNode _lyricFocusNode = FocusNode();
  final Random _rng = Random();

  bool _loading = true;
  HomeQuizMode _currentMode = HomeQuizMode.vocabulary;

  // Estado para modo Vocabulário
  QuizQuestion? _vocabQuestion;
  String? _selectedOption;
  bool? _isVocabCorrect;

  // Estado para modo Completar Frase da Música
  LyricFillQuestion? _lyricQuestion;
  bool _showLyricHint = false;
  bool _lyricSubmitted = false;
  bool? _isLyricCorrect;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _currentMode = widget.initialMode!;
    }
    _loadRandomQuestion(forceMode: widget.initialMode);
  }

  @override
  void didUpdateWidget(covariant HomeQuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_vocabQuestion == null && _lyricQuestion == null && widget.words.isNotEmpty) {
      _loadRandomQuestion(forceMode: widget.initialMode);
    }
  }

  @override
  void dispose() {
    _lyricController.dispose();
    _lyricFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRandomQuestion({HomeQuizMode? forceMode}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _selectedOption = null;
        _isVocabCorrect = null;
        _lyricSubmitted = false;
        _isLyricCorrect = null;
        _showLyricHint = false;
        _lyricController.clear();
      });
    }

    final targetMode = forceMode ??
        (widget.lockMode
            ? (widget.initialMode ?? _currentMode)
            : (_rng.nextBool()
                ? HomeQuizMode.lyricFill
                : HomeQuizMode.vocabulary));

    // MODO 1: COMPLETAR A MÚSICA (LYRIC FILL)
    if (targetMode == HomeQuizMode.lyricFill) {
      final userWordList = widget.words.take(20).map((w) => w.word).toList();
      final lyricQ = await _quizService.generateLyricFillQuestion(
        targetWords: userWordList.isNotEmpty ? userWordList : null,
      );

      if (!mounted) return;

      if (lyricQ != null) {
        setState(() {
          _currentMode = HomeQuizMode.lyricFill;
          _lyricQuestion = lyricQ;
          _vocabQuestion = null;
          _loading = false;
        });
        return;
      }

      // Se o modo estiver travado (ex: clicou em "Complete the Lyric"), NUNCA muda para vocabulário
      if (widget.lockMode) {
        setState(() {
          _currentMode = HomeQuizMode.lyricFill;
          _lyricQuestion = null;
          _vocabQuestion = null;
          _loading = false;
        });
        return;
      }
    }

    // MODO 2: DESAFIO DE VOCABULÁRIO (SPEED VOCABULARY)
    if (targetMode == HomeQuizMode.vocabulary || !widget.lockMode) {
      if (widget.words.isNotEmpty) {
        final pool = widget.words.take(25).toList();
        final candidate = pool[_rng.nextInt(pool.length)];

        final data = await _quizService.fetchTranslationData(
          candidate.word,
          sourceLang: candidate.language,
          targetLang: 'pt',
        );

        if (!mounted) return;

        if (data != null) {
          final question = _quizService.generateQuestion(
            data: data,
            trackName: candidate.trackName,
            artistName: candidate.artistName,
            forceMultipleChoice: true,
          );
          setState(() {
            _currentMode = HomeQuizMode.vocabulary;
            _vocabQuestion = question;
            _lyricQuestion = null;
            _loading = false;
          });
          return;
        }
      }

      // Se o modo estiver travado (ex: clicou em "Speed Vocabulary"), NUNCA muda para letra
      if (widget.lockMode) {
        setState(() {
          _currentMode = HomeQuizMode.vocabulary;
          _vocabQuestion = null;
          _lyricQuestion = null;
          _loading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _onSelectVocabOption(String option) {
    if (_selectedOption != null || _vocabQuestion == null) return;

    final correct = _vocabQuestion!.checkAnswer(option);
    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _selectedOption = option;
      _isVocabCorrect = correct;
    });
  }

  void _onSubmitLyricAnswer() {
    final text = _lyricController.text.trim();
    if (text.isEmpty || _lyricSubmitted || _lyricQuestion == null) return;

    _lyricFocusNode.unfocus();
    final correct = _lyricQuestion!.checkAnswer(text);
    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isLyricCorrect = correct;
      _lyricSubmitted = true;
    });
  }

  void _toggleQuizMode() {
    if (widget.lockMode) return;
    final nextMode = _currentMode == HomeQuizMode.vocabulary
        ? HomeQuizMode.lyricFill
        : HomeQuizMode.vocabulary;
    _loadRandomQuestion(forceMode: nextMode);
  }

  String _t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_loading && _vocabQuestion == null && _lyricQuestion == null && !widget.lockMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _loading
            ? SizedBox(
                height: 140,
                child: Center(
                  child: CupertinoActivityIndicator(
                    color: colors.primary,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Badges, Mode Toggle & Actions
                  Row(
                    children: [
                      // Badge dinâmico de acordo com o jogo ativo
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _currentMode == HomeQuizMode.lyricFill
                              ? const Color(0xFF007AFF).withValues(alpha: 0.15)
                              : AppTheme.spotifyGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentMode == HomeQuizMode.lyricFill
                                  ? CupertinoIcons.music_mic
                                  : CupertinoIcons.sparkles,
                              size: 13,
                              color: _currentMode == HomeQuizMode.lyricFill
                                  ? const Color(0xFF007AFF)
                                  : AppTheme.spotifyGreen,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _currentMode == HomeQuizMode.lyricFill
                                  ? _t('COMPLETAR A MÚSICA', 'COMPLETE THE LYRIC')
                                  : _t('DESAFIO RÁPIDO', 'QUICK CHALLENGE'),
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: _currentMode == HomeQuizMode.lyricFill
                                    ? const Color(0xFF007AFF)
                                    : AppTheme.spotifyGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Botão para alternar entre os jogos (oculto se o modo estiver travado)
                      if (!widget.lockMode) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            _currentMode == HomeQuizMode.lyricFill
                                ? CupertinoIcons.textformat_abc
                                : CupertinoIcons.music_note,
                            size: 18,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          tooltip: _currentMode == HomeQuizMode.lyricFill
                              ? _t('Modo vocabulário', 'Vocabulary mode')
                              : _t('Modo completar letra', 'Complete lyric mode'),
                          onPressed: _toggleQuizMode,
                        ),
                        const SizedBox(width: 2),
                      ],

                      // Botão recarregar outra pergunta
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          CupertinoIcons.arrow_2_circlepath,
                          size: 18,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        tooltip: _t('Outro desafio', 'Another challenge'),
                        onPressed: () => _loadRandomQuestion(
                          forceMode: widget.lockMode
                              ? (widget.initialMode ?? _currentMode)
                              : null,
                        ),
                      ),
                      if (widget.onDismissed != null) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            CupertinoIcons.xmark,
                            size: 18,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          tooltip: _t('Fechar', 'Close'),
                          onPressed: widget.onDismissed,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // CORPO DO JOGO: 1) COMPLETAR A MÚSICA OU 2) VOCABULÁRIO
                  if (_currentMode == HomeQuizMode.lyricFill)
                    if (_lyricQuestion != null)
                      _buildLyricFillContent(colors, isDark)
                    else
                      _buildEmptyLyricState(colors, isDark)
                  else
                    if (_vocabQuestion != null)
                      _buildVocabContent(colors, isDark)
                    else
                      _buildEmptyVocabState(colors, isDark),
                ],
              ),
      ),
    );
  }

  /// Conteúdo do jogo de completar a frase da música
  Widget _buildLyricFillContent(ColorScheme colors, bool isDark) {
    final q = _lyricQuestion!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Faixa e artista de onde a frase foi tirada
        Row(
          children: [
            Icon(
              CupertinoIcons.music_note_list,
              size: 14,
              color: const Color(0xFF007AFF),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${q.trackTitle} • ${q.artistName}',
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Frase da música com a lacuna
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
              width: 1,
            ),
          ),
          child: Text(
            '"${q.lineWithBlank}"',
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.2,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Dica de tradução da palavra no contexto da frase (apenas 1 palavra traduzida)
        if (q.wordTranslation != null && q.wordTranslation!.isNotEmpty) ...[
          if (!_showLyricHint)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(CupertinoIcons.lightbulb, size: 14, color: Color(0xFFFF9500)),
                label: Text(
                  _t('Ver dica de tradução', 'Show translation hint'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9500),
                  ),
                ),
                onPressed: () => setState(() => _showLyricHint = true),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.lightbulb_fill, size: 14, color: Color(0xFFFF9500)),
                  const SizedBox(width: 5),
                  Text(
                    _t(
                      'Dica: significa "${q.wordTranslation}"',
                      'Hint: means "${q.wordTranslation}"',
                    ),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF9500),
                    ),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 12),

        // Campo para digitar a palavra
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _lyricController,
                focusNode: _lyricFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onSubmitLyricAnswer(),
                placeholder: _t('Digite a palavra que falta...', 'Type the missing word...'),
                placeholderStyle: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 15,
                  color: colors.onSurface,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _lyricSubmitted ? null : _onSubmitLyricAnswer,
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

        // Feedback pós-resposta
        if (_lyricSubmitted) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isLyricCorrect == true
                  ? AppTheme.spotifyGreen.withValues(alpha: 0.12)
                  : Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isLyricCorrect == true
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
                      _isLyricCorrect == true
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.info_circle_fill,
                      size: 18,
                      color: _isLyricCorrect == true
                          ? AppTheme.spotifyGreen
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLyricCorrect == true
                            ? _t('Acertou em cheio! 🎉', 'Spot on! 🎉')
                            : _t('A palavra correta é: "${q.targetWord}"', 'The correct word is: "${q.targetWord}"'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _loadRandomQuestion(
                        forceMode: widget.lockMode ? HomeQuizMode.lyricFill : null,
                      ),
                      child: Text(
                        _t('Próxima', 'Next'),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _t('Frase completa: "${q.fullLine}"', 'Full line: "${q.fullLine}"'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Conteúdo do jogo de vocabulário tradicional
  Widget _buildVocabContent(ColorScheme colors, bool isDark) {
    final q = _vocabQuestion!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt text
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 16,
              color: colors.onSurface,
              letterSpacing: -0.2,
            ),
            children: [
              TextSpan(
                text: _t('Qual o significado de ', 'What is the meaning of '),
              ),
              TextSpan(
                text: '"${q.word}"',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),

        if (q.trackName != null && q.trackName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _t(
              'Palavra aprendida em: ${q.trackName}',
              'Word learned in: ${q.trackName}',
            ),
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 16),

        // Grid de opções responsivo (distribui em 2 colunas no mobile ou 1 coluna se tela muito estreita)
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final availableWidth = constraints.maxWidth;
            final isTwoColumn = availableWidth >= 220;
            final itemWidth = isTwoColumn
                ? ((availableWidth - spacing) / 2).floorToDouble()
                : availableWidth;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: q.options.map((option) {
                final isSelected = _selectedOption == option;
                final isOptionCorrect = q.checkAnswer(option);

                Color bg = isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x0A000000);
                Color border = isDark
                    ? const Color(0x26FFFFFF)
                    : const Color(0x14000000);
                Color textColor = colors.onSurface;

                if (_selectedOption != null) {
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

                return SizedBox(
                  width: itemWidth,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectedOption == null
                          ? () => _onSelectVocabOption(option)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  fontSize: 14,
                                  fontWeight: isSelected ||
                                          (_selectedOption != null &&
                                              isOptionCorrect)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedOption != null && isOptionCorrect)
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 16,
                                color: AppTheme.spotifyGreen,
                              )
                            else if (isSelected && !isOptionCorrect)
                              const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        // Feedback pós-resposta
        if (_selectedOption != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isVocabCorrect == true
                  ? AppTheme.spotifyGreen.withValues(alpha: 0.1)
                  : Colors.orangeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isVocabCorrect == true
                      ? CupertinoIcons.check_mark_circled
                      : CupertinoIcons.info_circle,
                  size: 18,
                  color: _isVocabCorrect == true
                      ? AppTheme.spotifyGreen
                      : Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isVocabCorrect == true
                        ? _t(
                            q.allAcceptedTranslations.length > 1
                                ? 'Boa! "${q.word}" também pode significar: ${q.allAcceptedTranslations.take(4).join(", ")}'
                                : 'Excelente! Mandou muito bem! 🎉',
                            q.allAcceptedTranslations.length > 1
                                ? 'Nice! "${q.word}" can also mean: ${q.allAcceptedTranslations.take(4).join(", ")}'
                                : 'Awesome! Well done! 🎉',
                          )
                        : _t(
                            'A resposta correta é: "${q.correctAnswer}". ${q.allAcceptedTranslations.length > 1 ? "Outros significados: ${q.allAcceptedTranslations.take(3).join(', ')}" : ""}',
                            'Correct answer is: "${q.correctAnswer}".',
                          ),
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _loadRandomQuestion(
                    forceMode: widget.lockMode ? HomeQuizMode.vocabulary : null,
                  ),
                  child: Text(
                    _t('Próxima', 'Next'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.spotifyGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyLyricState(ColorScheme colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.music_mic,
            size: 36,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            _t('Buscando versos de músicas...', 'Searching song lyrics...'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Ouça algumas músicas no app para desbloquear novos desafios de completar letras!',
              'Play some songs in the app to unlock new fill-in-the-lyric challenges!',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 14),
            label: Text(_t('Tentar novamente', 'Try again')),
            onPressed: () => _loadRandomQuestion(forceMode: HomeQuizMode.lyricFill),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVocabState(ColorScheme colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.sparkles,
            size: 36,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            _t('Nenhuma palavra salva ainda', 'No saved words yet'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Ao ouvir músicas, toque nas palavras que você quer aprender para treinar aqui!',
              'While listening to songs, tap words you want to learn to practice them here!',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 14),
            label: Text(_t('Tentar novamente', 'Try again')),
            onPressed: () => _loadRandomQuestion(forceMode: HomeQuizMode.vocabulary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../core/models/cefr_level.dart';
import '../core/models/known_word_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../widgets/home_quiz_card.dart';
import '../widgets/language_flag.dart';
import '../widgets/weekly_consistency_badge.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final KnownWordsRepository _wordsRepo = KnownWordsRepository();
  final LanguageService _languageService = LanguageService();

  List<KnownWordModel> _words = [];
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _load();
    KnownWordsRepository.changes.addListener(_load);
  }

  @override
  void dispose() {
    KnownWordsRepository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final words = await _wordsRepo.getKnownWordsList();
      final targetLang = await _languageService.getTargetLanguage();
      if (!mounted) return;
      setState(() {
        _words = words;
        _selectedLanguage = targetLang;
      });
    } catch (_) {}
  }

  String _t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  void _openInteractiveGame(HomeQuizMode? mode, {bool lockMode = true}) {
    HapticFeedback.lightImpact();
    // Exibe um modal dinâmico para jogar o minigame escolhido
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x26FFFFFF)
                  : const Color(0x14000000),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              HomeQuizCard(
                words: _words,
                initialMode: mode,
                lockMode: lockMode,
                onDismissed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCefrRoadmapModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;

    final langWords = _words.where((w) => w.language == _selectedLanguage).length;
    final currentLevel = CefrLevel.fromWordCount(langWords);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
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
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                _t('Escala Científica CEFR', 'CEFR Scientific Roadmap'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'Baseado nos marcos lexicais de Paul Nation e Milton & Alexiou para compreensão auditiva e de leitura.',
                  'Based on Paul Nation and Milton & Alexiou lexical benchmarks for listening and reading comprehension.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: CefrLevel.all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lvl = CefrLevel.all[index];
                    final isReached = langWords >= lvl.minWords;
                    final isCurrent = lvl.type == currentLevel.type;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? lvl.badgeColor.withValues(alpha: isDark ? 0.2 : 0.12)
                            : isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCurrent
                              ? lvl.badgeColor
                              : isDark
                                  ? const Color(0x26FFFFFF)
                                  : const Color(0x14000000),
                          width: isCurrent ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: lvl.badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              lvl.code,
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: lvl.badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lvl.localizedTitle(langCode),
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontSF,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      lvl.minWords == 0
                                          ? '0 - 500'
                                          : '${lvl.minWords}+ ${_t("palavras", "words")}',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontSF,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lvl.localizedDescription(langCode),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isReached) ...[
                            const SizedBox(width: 10),
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: lvl.badgeColor,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _t('Entendi', 'Got it'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;

    // Estatísticas por idioma
    final wordsByLang = <String, int>{};
    for (final w in _words) {
      wordsByLang.update(w.language, (c) => c + 1, ifAbsent: () => 1);
    }
    final availableLanguages = wordsByLang.keys.toList();
    if (!availableLanguages.contains(_selectedLanguage) && availableLanguages.isNotEmpty) {
      _selectedLanguage = availableLanguages.first;
    }

    final currentWordCount = wordsByLang[_selectedLanguage] ?? _words.length;
    final currentCefr = CefrLevel.fromWordCount(currentWordCount);
    final nextCefr = CefrLevel.nextLevel(currentCefr);

    // Cálculo do progresso no nível atual
    double progressPercent = 1.0;
    int remainingForNext = 0;
    if (nextCefr != null) {
      final currentBase = currentCefr.minWords;
      final targetGoal = nextCefr.minWords;
      final span = targetGoal - currentBase;
      final progressInStage = (currentWordCount - currentBase).clamp(0, span);
      progressPercent = span > 0 ? (progressInStage / span) : 1.0;
      remainingForNext = (targetGoal - currentWordCount).clamp(0, targetGoal);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Games & Metas', 'Games & Goals'),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t(
                              'Evolução de fluência, consistência e minigames',
                              'Fluency progress, consistency and minigames',
                            ),
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    WeeklyConsistencyBadge(words: _words),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // CARD 1: NÍVEL DE FLUÊNCIA CEFR & METAS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Idioma seletor & badge de nível
                      Row(
                        children: [
                          if (availableLanguages.length > 1) ...[
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedLanguage,
                                icon: const Icon(CupertinoIcons.chevron_down, size: 14),
                                items: availableLanguages.map((code) {
                                  return DropdownMenuItem(
                                    value: code,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LanguageFlag(countryCode: code, width: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          code.toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontSF,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedLanguage = val);
                                },
                              ),
                            ),
                            const Spacer(),
                          ] else ...[
                            Row(
                              children: [
                                LanguageFlag(countryCode: _selectedLanguage, width: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedLanguage.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                          ],

                          // Badge com cor do nível CEFR
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: currentCefr.badgeColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: currentCefr.badgeColor.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.rosette,
                                  size: 14,
                                  color: currentCefr.badgeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  currentCefr.type == CefrLevelType.starter
                                      ? currentCefr.localizedTitle(langCode)
                                      : '${currentCefr.code} • ${currentCefr.localizedTitle(langCode)}',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: currentCefr.badgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Contador de palavras e título
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currentWordCount',
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _t('palavras dominadas', 'known words'),
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Barra de progresso para a próxima meta
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 9,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          color: currentCefr.badgeColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Legenda do progresso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nextCefr != null
                                ? _t(
                                    'Meta para ${nextCefr.code}: faltam $remainingForNext palavras',
                                    'Goal for ${nextCefr.code}: $remainingForNext words left',
                                  )
                                : _t('Nível máximo alcançado!', 'Max mastery level reached!'),
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${(progressPercent * 100).toInt()}%',
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: currentCefr.badgeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botão ver roadmap CEFR completo
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                            ),
                          ),
                          onPressed: () => _showCefrRoadmapModal(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.map, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _t('Ver todos os marcos CEFR (A1 a C2)', 'View all CEFR milestones (A1-C2)'),
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // SEÇÃO: HUB DE MINIGAMES
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  _t('Minigames & Treinos', 'Minigames & Practice'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),

              // Game 1: Mix de Letras & Vocabulário (Misturar modos)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildGameCard(
                  context,
                  title: _t('Mix: Letras & Vocabulário', 'Mix: Lyrics & Vocab'),
                  subtitle: _t(
                    'Mistura aleatoriamente desafios de completar frases de músicas e testes rápidos de vocabulário.',
                    'Randomly mixes fill-in-the-lyric challenges and quick vocabulary quizzes.',
                  ),
                  icon: CupertinoIcons.shuffle,
                  accentColor: const Color(0xFFBF5AF2),
                  badge: _t('RECOMENDADO', 'RECOMMENDED'),
                  onPlay: () => _openInteractiveGame(null, lockMode: false),
                ),
              ),

              // Game 2: Completar a Frase da Música (Apenas Letras)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildGameCard(
                  context,
                  title: _t('Completar a Música', 'Complete the Lyric'),
                  subtitle: _t(
                    'Modo focado apenas em identificar e digitar a palavra que falta nas linhas das músicas.',
                    'Focus mode: identify and type the missing word from song lines only.',
                  ),
                  icon: CupertinoIcons.music_mic,
                  accentColor: const Color(0xFF007AFF),
                  badge: _t('SÓ LETRAS', 'LYRICS ONLY'),
                  onPlay: () => _openInteractiveGame(HomeQuizMode.lyricFill, lockMode: true),
                ),
              ),

              // Game 3: Desafio Rápido de Vocabulário (Apenas Vocabulário)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildGameCard(
                  context,
                  title: _t('Desafio de Vocabulário', 'Speed Vocabulary'),
                  subtitle: _t(
                    'Modo focado apenas em testar sua memória com perguntas de múltipla escolha das palavras salvas.',
                    'Focus mode: test retention with multiple-choice questions only.',
                  ),
                  icon: CupertinoIcons.sparkles,
                  accentColor: AppTheme.spotifyGreen,
                  badge: _t('SÓ VOCABULÁRIO', 'VOCAB ONLY'),
                  onPlay: () => _openInteractiveGame(HomeQuizMode.vocabulary, lockMode: true),
                ),
              ),

              const SizedBox(height: 20),

              // SEÇÃO: DICAS DE RETENÇÃO E CIÊNCIA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.lightbulb_fill,
                          color: Color(0xFFFF9500),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('Dica de Aprendizado', 'Learning Tip'),
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _t(
                                'A recordação ativa (tentar lembrar a palavra da música) fixa o vocabulário até 3x mais rápido do que apenas reler a tradução.',
                                'Active recall (trying to retrieve the lyric word) anchors vocabulary up to 3x faster than just reading translations.',
                              ),
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
    required VoidCallback onPlay,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: onPlay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.play_fill, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _t('Jogar Agora', 'Play Now'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

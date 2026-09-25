import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../core/models/cefr_level.dart';
import '../core/models/known_word_model.dart';
import '../core/services/app_strings.dart';
import '../core/services/language_service.dart';
import 'language_flag.dart';

class DayActivity {
  final DateTime date;
  final String shortLabel;
  final String fullLabel;
  final int count;
  final bool isToday;
  final bool isFuture;

  const DayActivity({
    required this.date,
    required this.shortLabel,
    required this.fullLabel,
    required this.count,
    required this.isToday,
    required this.isFuture,
  });
}

/// Widget exibido no topo da tela de início e na tela de Games,
/// mostrando os 7 dias da semana atual no estilo de contribuição do GitHub
/// e o contador de semanas consecutivas (ofensiva semanal).
class WeeklyConsistencyBadge extends StatelessWidget {
  final List<KnownWordModel> words;
  final String? languageFilter;

  const WeeklyConsistencyBadge({
    super.key,
    required this.words,
    this.languageFilter,
  });

  static DateTime _startOfWeek(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static int calculateStreak(List<KnownWordModel> words, [DateTime? refDate]) {
    if (words.isEmpty) return 0;
    final now = refDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Mapeia os dias únicos em que houve palavras praticadas/marcadas
    final activeDays = <DateTime>{};
    for (final w in words) {
      activeDays.add(DateTime(w.createdAt.year, w.createdAt.month, w.createdAt.day));
    }

    if (activeDays.isEmpty) return 0;

    final hasToday = activeDays.contains(today);
    final hasYesterday = activeDays.contains(yesterday);

    // Se não praticou nem hoje nem ontem, a sequência de dias consecutivos é 0
    if (!hasToday && !hasYesterday) {
      return 0;
    }

    int streak = 0;
    DateTime checkDay = hasToday ? today : yesterday;

    while (activeDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static List<DayActivity> getWeekDaysForWords(
    BuildContext context,
    List<KnownWordModel> wordsList,
  ) {
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = _startOfWeek(now);

    final shortPt = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final shortEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final fullPt = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    final fullEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      final isCurrentDay = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isFutureDay = date.isAfter(today);

      final count = wordsList.where((w) {
        return w.createdAt.year == date.year &&
            w.createdAt.month == date.month &&
            w.createdAt.day == date.day;
      }).length;

      return DayActivity(
        date: date,
        shortLabel: isPt ? shortPt[index] : shortEn[index],
        fullLabel: isPt ? fullPt[index] : fullEn[index],
        count: count,
        isToday: isCurrentDay,
        isFuture: isFutureDay,
      );
    });
  }

  /// Retorna o tom de azul de acordo com a intensidade de palavras praticadas no dia (estilo GitHub).
  /// Escala gradativa suave: desde um azul bem fraquinho, bem leve, leve, claro, até azul reluzente no máximo (sem tons pretos/escuros).
  static Color getSquareColor(int count, bool isDark) {
    if (count == 0) {
      return isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000);
    } else if (count == 1) {
      // Nível 1: azul bem fraquinho
      return isDark ? const Color(0xFF285680) : const Color(0xFFD4E8FC);
    } else if (count <= 3) {
      // Nível 2: azul bem leve
      return isDark ? const Color(0xFF256BB3) : const Color(0xFFA6D1FA);
    } else if (count <= 6) {
      // Nível 3: azul leve / claro
      return isDark ? const Color(0xFF1E86E8) : const Color(0xFF62AFFE);
    } else if (count <= 10) {
      // Nível 4: azul clássico vibrante
      return isDark ? const Color(0xFF007AFF) : const Color(0xFF147BF3);
    } else {
      // Nível 5: azul reluzente no máximo (11+ palavras)
      return isDark ? const Color(0xFF64D2FF) : const Color(0xFF005AC2);
    }
  }

  static void showConsistencyModal(
    BuildContext context, {
    required List<KnownWordModel> words,
    String? initialLanguage,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _WeeklyConsistencyModal(
        words: words,
        initialLanguage: initialLanguage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPt = Localizations.localeOf(context).languageCode == 'pt';

    final effectiveWords = languageFilter != null
        ? words.where((w) => w.language == languageFilter).toList()
        : words;

    final days = getWeekDaysForWords(context, effectiveWords);
    final streak = calculateStreak(effectiveWords);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showConsistencyModal(
          context,
          words: words,
          initialLanguage: languageFilter,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 7 GitHub-style consistency squares
              Row(
                mainAxisSize: MainAxisSize.min,
                children: days.map((day) {
                  final color = getSquareColor(day.count, isDark);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.8),
                    child: Container(
                      width: 9.5,
                      height: 9.5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2.5),
                        border: day.isToday
                            ? Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.black87,
                                width: 1.2,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(width: 8),

              // Vertical divider
              Container(
                width: 1,
                height: 14,
                color: isDark
                    ? const Color(0x26FFFFFF)
                    : const Color(0x14000000),
              ),

              const SizedBox(width: 7),

              // Streak Number & label (sem foguinho)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: streak > 0
                          ? const Color(0xFF007AFF)
                          : colors.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    isPt ? ' d' : 'd',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal com detalhes da sequência semanal, progresso no idioma selecionado e atalho para histórico anual
class _WeeklyConsistencyModal extends StatefulWidget {
  final List<KnownWordModel> words;
  final String? initialLanguage;

  const _WeeklyConsistencyModal({
    required this.words,
    this.initialLanguage,
  });

  @override
  State<_WeeklyConsistencyModal> createState() => _WeeklyConsistencyModalState();
}

class _WeeklyConsistencyModalState extends State<_WeeklyConsistencyModal> {
  late String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  void _showAnnualHistoryModal(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnualContributionSheet(
        words: widget.words,
        initialLanguage: _selectedLanguage,
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required bool isSelected,
    required String label,
    IconData? icon,
    String? flagCode,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF)
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : (isDark ? const Color(0x26FFFFFF) : const Color(0x14000000)),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ] else if (flagCode != null) ...[
              LanguageFlag(countryCode: flagCode, width: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isPt = langCode == 'pt';

    // Lista de idiomas existentes no repertório do usuário
    final availableLanguages = <String>{};
    for (final w in widget.words) {
      if (w.language.isNotEmpty) {
        availableLanguages.add(w.language);
      }
    }
    if (_selectedLanguage != null && _selectedLanguage!.isNotEmpty) {
      availableLanguages.add(_selectedLanguage!);
    }
    final sortedLanguages = availableLanguages.toList()..sort();

    // Filtra palavras pelo idioma ativo no modal
    final filteredWords = _selectedLanguage != null
        ? widget.words.where((w) => w.language == _selectedLanguage).toList()
        : widget.words;

    final streak = WeeklyConsistencyBadge.calculateStreak(filteredWords);
    final days = WeeklyConsistencyBadge.getWeekDaysForWords(context, filteredWords);
    final totalWordsThisWeek = days.fold<int>(0, (sum, d) => sum + d.count);

    // Dados de progresso CEFR se um idioma específico estiver selecionado
    CefrLevel? currentCefr;
    CefrLevel? nextCefr;
    double progressPercent = 1.0;
    int remainingForNext = 0;
    int langWordCount = 0;

    if (_selectedLanguage != null) {
      langWordCount = filteredWords.length;
      currentCefr = CefrLevel.fromWordCount(langWordCount);
      nextCefr = CefrLevel.nextLevel(currentCefr);

      if (nextCefr != null) {
        final currentBase = currentCefr.minWords;
        final targetGoal = nextCefr.minWords;
        final span = targetGoal - currentBase;
        final progressInStage = (langWordCount - currentBase).clamp(0, span);
        progressPercent = span > 0 ? (progressInStage / span) : 1.0;
        remainingForNext = (targetGoal - langWordCount).clamp(0, targetGoal);
      }
    }

    final selectedLangName = _selectedLanguage != null
        ? localizedLanguageName(context, _selectedLanguage!)
        : null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Seletor de Idioma em chips horizontais (Todos os Idiomas / Idiomas Individuais)
              if (sortedLanguages.isNotEmpty) ...[
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildFilterChip(
                        context: context,
                        isSelected: _selectedLanguage == null,
                        label: isPt ? 'Todos os Idiomas' : 'All Languages',
                        icon: CupertinoIcons.globe,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedLanguage = null);
                        },
                      ),
                      for (final code in sortedLanguages) ...[
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          context: context,
                          isSelected: _selectedLanguage == code,
                          label: localizedLanguageName(context, code),
                          flagCode: supportedLanguages
                                  .cast<LanguagePreference?>()
                                  .firstWhere((l) => l?.code == code, orElse: () => null)
                                  ?.flagCode ??
                              code,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedLanguage = code);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Streak circle badge & number (sem foguinho)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$streak',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Título dinâmico por idioma ou global (dias consecutivos)
              Text(
                streak == 0
                    ? (_selectedLanguage != null
                        ? (isPt
                            ? 'Comece sua sequência em $selectedLangName!'
                            : 'Start your streak in $selectedLangName!')
                        : (isPt
                            ? 'Comece sua sequência diária!'
                            : 'Start your daily streak!'))
                    : streak == 1
                        ? (_selectedLanguage != null
                            ? (isPt
                                ? '1 dia praticado em $selectedLangName!'
                                : '1 day streak in $selectedLangName!')
                            : (isPt
                                ? '1 dia de ofensiva!'
                                : '1 day streak!'))
                        : (_selectedLanguage != null
                            ? (isPt
                                ? '$streak dias consecutivos em $selectedLangName!'
                                : '$streak consecutive days in $selectedLangName!')
                            : (isPt
                                ? '$streak dias consecutivos!'
                                : '$streak consecutive days!')),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                _selectedLanguage != null
                    ? (isPt
                        ? 'Você marcou $totalWordsThisWeek ${totalWordsThisWeek == 1 ? "palavra" : "palavras"} em $selectedLangName nesta semana.'
                        : 'You learned $totalWordsThisWeek ${totalWordsThisWeek == 1 ? "word" : "words"} in $selectedLangName this week.')
                    : (isPt
                        ? 'Você marcou $totalWordsThisWeek ${totalWordsThisWeek == 1 ? "palavra" : "palavras"} nesta semana.'
                        : 'You learned $totalWordsThisWeek ${totalWordsThisWeek == 1 ? "word" : "words"} this week.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // CARD DE PROGRESSO ESPECÍFICO DO IDIOMA SELECIONADO
              if (_selectedLanguage != null && currentCefr != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x26FFFFFF)
                          : const Color(0x14000000),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LanguageFlag(
                            countryCode: supportedLanguages
                                    .cast<LanguagePreference?>()
                                    .firstWhere((l) => l?.code == _selectedLanguage, orElse: () => null)
                                    ?.flagCode ??
                                _selectedLanguage!,
                            width: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedLangName ?? _selectedLanguage!.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$langWordCount ${isPt ? (langWordCount == 1 ? "palavra dominada" : "palavras dominadas") : (langWordCount == 1 ? "word mastered" : "words mastered")}',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentCefr.badgeColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: currentCefr.badgeColor.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.rosette,
                                  size: 13,
                                  color: currentCefr.badgeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentCefr.type == CefrLevelType.starter
                                      ? currentCefr.localizedTitle(langCode)
                                      : '${currentCefr.code} • ${currentCefr.localizedTitle(langCode)}',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: currentCefr.badgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          color: currentCefr.badgeColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nextCefr != null
                                ? (isPt
                                    ? 'Meta para ${nextCefr.code}: faltam $remainingForNext palavras'
                                    : 'Goal for ${nextCefr.code}: $remainingForNext words left')
                                : (isPt ? 'Nível máximo alcançado!' : 'Max mastery reached!'),
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${(progressPercent * 100).toInt()}%',
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: currentCefr.badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Week day breakdown cards
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x26FFFFFF)
                        : const Color(0x14000000),
                  ),
                ),
                child: Column(
                  children: days.map((d) {
                    final color = WeeklyConsistencyBadge.getSquareColor(d.count, isDark);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              border: d.isToday
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.fullLabel + (d.isToday ? (isPt ? ' (Hoje)' : ' (Today)') : ''),
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 14,
                                fontWeight:
                                    d.isToday ? FontWeight.w700 : FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            d.count > 0
                                ? '${d.count} ${isPt ? "palavras" : "words"}'
                                : (d.isFuture ? '-' : (isPt ? '0 palavras' : '0 words')),
                            style: TextStyle(
                              fontFamily: AppTheme.fontSF,
                              fontSize: 13,
                              fontWeight:
                                  d.count > 0 ? FontWeight.w700 : FontWeight.w400,
                              color: d.count > 0
                                  ? const Color(0xFF007AFF)
                                  : colors.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Legenda de intensidade estilo GitHub: Menos [][][][][] Mais
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isPt ? 'Menos' : 'Less',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 11,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...[0, 1, 3, 6, 9, 12].map((cnt) {
                    return Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: WeeklyConsistencyBadge.getSquareColor(cnt, isDark),
                        borderRadius: BorderRadius.circular(2.5),
                        border: cnt == 0
                            ? Border.all(
                                color: isDark
                                    ? const Color(0x33FFFFFF)
                                    : const Color(0x1F000000),
                                width: 0.6,
                              )
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    isPt ? 'Mais' : 'More',
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 11,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Botão ver histórico anual completo (52 semanas estilo GitHub)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0x33FFFFFF)
                          : const Color(0x1F000000),
                    ),
                  ),
                  onPressed: () => _showAnnualHistoryModal(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        isPt
                            ? 'Ver histórico anual completo (52 semanas)'
                            : 'View full annual history (52 weeks)',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Button Fechar / Continuar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isPt ? 'Continuar praticando' : 'Keep practicing',
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
}

/// Modal com o gráfico anual de contribuição de 52 semanas, idêntico ao GitHub, com filtro por idioma
class AnnualContributionSheet extends StatefulWidget {
  final List<KnownWordModel> words;
  final String? initialLanguage;

  const AnnualContributionSheet({
    super.key,
    required this.words,
    this.initialLanguage,
  });

  @override
  State<AnnualContributionSheet> createState() => _AnnualContributionSheetState();
}

class _AnnualContributionSheetState extends State<AnnualContributionSheet> {
  final ScrollController _scrollController = ScrollController();
  late String? _selectedLanguageFilter;
  DateTime? _selectedDate;
  int? _selectedCount;

  @override
  void initState() {
    super.initState();
    _selectedLanguageFilter = widget.initialLanguage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt, bool isPt) {
    const ptMonths = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    const enMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final m = isPt ? ptMonths[dt.month - 1] : enMonths[dt.month - 1];
    return isPt ? '${dt.day} de $m de ${dt.year}' : '$m ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPt = Localizations.localeOf(context).languageCode == 'pt';

    // Idiomas disponíveis para filtrar no gráfico anual
    final availableLanguages = <String>{};
    for (final w in widget.words) {
      if (w.language.isNotEmpty) {
        availableLanguages.add(w.language);
      }
    }
    if (_selectedLanguageFilter != null && _selectedLanguageFilter!.isNotEmpty) {
      availableLanguages.add(_selectedLanguageFilter!);
    }
    final sortedLanguages = availableLanguages.toList()..sort();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final startMonday = currentMonday.subtract(const Duration(days: 51 * 7));

    // Filtra palavras pelo idioma selecionado
    final filteredWords = _selectedLanguageFilter != null
        ? widget.words.where((w) => w.language == _selectedLanguageFilter).toList()
        : widget.words;

    // Mapeamento de contagem por dia
    final Map<DateTime, int> dayCounts = {};
    for (final w in filteredWords) {
      final d = DateTime(w.createdAt.year, w.createdAt.month, w.createdAt.day);
      dayCounts[d] = (dayCounts[d] ?? 0) + 1;
    }

    final totalYearWords = dayCounts.entries
        .where((e) => !e.key.isBefore(startMonday) && !e.key.isAfter(today))
        .fold<int>(0, (sum, e) => sum + e.value);

    int maxDayWords = 0;
    for (final e in dayCounts.entries) {
      if (!e.key.isBefore(startMonday) && !e.key.isAfter(today)) {
        if (e.value > maxDayWords) maxDayWords = e.value;
      }
    }

    const shortMonthsPt = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    const shortMonthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final shortMonths = isPt ? shortMonthsPt : shortMonthsEn;

    final weekDaysLabels = isPt ? ['', 'Seg', '', 'Qua', '', 'Sex', ''] : ['', 'Mon', '', 'Wed', '', 'Fri', ''];

    final selectedLangName = _selectedLanguageFilter != null
        ? localizedLanguageName(context, _selectedLanguageFilter!)
        : null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 900,
        ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header: Title & Close Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPt ? 'Histórico Anual de Aprendizado' : 'Annual Learning History',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedLanguageFilter != null
                            ? (isPt
                                ? '$totalYearWords palavras praticadas em $selectedLangName nas últimas 52 semanas'
                                : '$totalYearWords words practiced in $selectedLangName in the last 52 weeks')
                            : (isPt
                                ? '$totalYearWords palavras praticadas nas últimas 52 semanas'
                                : '$totalYearWords words practiced in the last 52 weeks'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filtro por idioma em chips
            if (sortedLanguages.isNotEmpty) ...[
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedLanguageFilter = null;
                          _selectedDate = null;
                          _selectedCount = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedLanguageFilter == null
                              ? const Color(0xFF007AFF)
                              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedLanguageFilter == null
                                ? const Color(0xFF007AFF)
                                : (isDark ? const Color(0x26FFFFFF) : const Color(0x14000000)),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.globe,
                              size: 13,
                              color: _selectedLanguageFilter == null ? Colors.white : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPt ? 'Todos os Idiomas' : 'All Languages',
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                fontSize: 11,
                                fontWeight: _selectedLanguageFilter == null ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedLanguageFilter == null ? Colors.white : colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final code in sortedLanguages) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedLanguageFilter = code;
                            _selectedDate = null;
                            _selectedCount = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedLanguageFilter == code
                                ? const Color(0xFF007AFF)
                                : (isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedLanguageFilter == code
                                  ? const Color(0xFF007AFF)
                                  : (isDark ? const Color(0x26FFFFFF) : const Color(0x14000000)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LanguageFlag(
                                countryCode: supportedLanguages
                                        .cast<LanguagePreference?>()
                                        .firstWhere((l) => l?.code == code, orElse: () => null)
                                        ?.flagCode ??
                                    code,
                                width: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                localizedLanguageName(context, code),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  fontSize: 11,
                                  fontWeight: _selectedLanguageFilter == code ? FontWeight.w700 : FontWeight.w500,
                                  color: _selectedLanguageFilter == code ? Colors.white : colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Card da Matriz de Contribuição GitHub
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grid com dias da semana na esquerda e scroll horizontal
                  SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Coluna de rótulos dos dias (Seg, Qua, Sex)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, right: 6),
                          child: Column(
                            children: List.generate(7, (rowIndex) {
                              return Container(
                                height: 11.5,
                                margin: const EdgeInsets.symmetric(vertical: 2.2),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  weekDaysLabels[rowIndex],
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // Colunas das 52 semanas com cabeçalho de meses
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Linha dos meses
                            Row(
                              children: List.generate(52, (colIndex) {
                                final monday = startMonday.add(Duration(days: colIndex * 7));
                                final isFirstWeekOfMonth = monday.day <= 7;
                                return SizedBox(
                                  width: 15.1,
                                  child: isFirstWeekOfMonth
                                      ? Text(
                                          shortMonths[monday.month - 1],
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontSF,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                );
                              }),
                            ),
                            const SizedBox(height: 6),

                            // Grid dos quadradinhos (7 linhas x 52 colunas)
                            Row(
                              children: List.generate(52, (colIndex) {
                                return Column(
                                  children: List.generate(7, (rowIndex) {
                                    final dayDate = startMonday.add(
                                      Duration(days: colIndex * 7 + rowIndex),
                                    );
                                    final isToday = dayDate.year == today.year &&
                                        dayDate.month == today.month &&
                                        dayDate.day == today.day;
                                    final isFuture = dayDate.isAfter(today);
                                    final count = isFuture ? 0 : (dayCounts[dayDate] ?? 0);
                                    final isSelected = _selectedDate != null &&
                                        _selectedDate!.year == dayDate.year &&
                                        _selectedDate!.month == dayDate.month &&
                                        _selectedDate!.day == dayDate.day;

                                    Color color;
                                    if (isFuture) {
                                      color = isDark ? const Color(0x0AFFFFFF) : const Color(0x06000000);
                                    } else {
                                      color = WeeklyConsistencyBadge.getSquareColor(count, isDark);
                                    }

                                    return GestureDetector(
                                      onTap: isFuture
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _selectedDate = dayDate;
                                                _selectedCount = count;
                                              });
                                            },
                                      child: Container(
                                        width: 11.5,
                                        height: 11.5,
                                        margin: const EdgeInsets.all(1.8),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(2.5),
                                          border: isSelected
                                              ? Border.all(
                                                  color: Colors.amberAccent,
                                                  width: 1.6,
                                                )
                                              : isToday
                                                  ? Border.all(
                                                      color: isDark ? Colors.white : Colors.black87,
                                                      width: 1.2,
                                                    )
                                                  : count == 0 && !isFuture
                                                      ? Border.all(
                                                          color: isDark
                                                              ? const Color(0x1AFFFFFF)
                                                              : const Color(0x12000000),
                                                          width: 0.6,
                                                        )
                                                      : null,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Barra informativa interativa (detalhe do dia selecionado ou resumo)
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        size: 14,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? '${_formatDate(_selectedDate!, isPt)}: ${_selectedCount == 0 ? (isPt ? "Nenhuma palavra aprendida" : "No words learned") : "$_selectedCount ${isPt ? (_selectedCount == 1 ? "palavra aprendida" : "palavras aprendidas") : (_selectedCount == 1 ? "word learned" : "words learned")}"}${_selectedLanguageFilter != null ? " ($selectedLangName)" : ""}'
                              : isPt
                                  ? 'Toque em qualquer quadradinho para ver detalhes do dia'
                                  : 'Tap any square to inspect details for that day',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 12,
                            fontWeight: _selectedDate != null ? FontWeight.w700 : FontWeight.w500,
                            color: _selectedDate != null ? colors.onSurface : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Legenda Menos / Mais
                      Text(
                        isPt ? 'Menos' : 'Less',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 10,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ...[0, 1, 3, 6, 9, 12].map((cnt) {
                        return Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          decoration: BoxDecoration(
                            color: WeeklyConsistencyBadge.getSquareColor(cnt, isDark),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        isPt ? 'Mais' : 'More',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontSize: 10,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Badges informativos: Máximo em um dia & Total
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x14FFFFFF) : const Color(0x08000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPt ? 'Pico em 1 dia' : 'Best single day',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$maxDayWords ${isPt ? "palavras" : "words"}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x14FFFFFF) : const Color(0x08000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPt ? 'Total no ano' : 'Yearly total',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalYearWords ${isPt ? "palavras" : "words"}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

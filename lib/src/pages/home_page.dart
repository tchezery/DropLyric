import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/cefr_level.dart';
import '../core/models/known_word_model.dart';
import '../core/models/learning_summary.dart';
import '../core/models/track_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../core/services/saved_tracks.dart';
import '../core/services/quiz_service.dart';
import '../core/services/spotify_session.dart';
import '../widgets/track_card.dart';
import '../widgets/language_flag.dart';
import '../widgets/home_quiz_card.dart';
import '../widgets/weekly_consistency_badge.dart';
import 'player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final _saved = SavedTracks.instance;
  final _repository = KnownWordsRepository();
  List<KnownWordModel> _words = [];
  bool _loading = true;
  bool _failed = false;
  bool _showQuizCard = true;
  PageRoute? _route;
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  void initState() {
    super.initState();
    _load();
    KnownWordsRepository.changes.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      AppRoutes.routeObserver.unsubscribe(this);
      _route = route;
      AppRoutes.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _load();

  @override
  void dispose() {
    KnownWordsRepository.changes.removeListener(_load);
    AppRoutes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      await _saved.ready;
      final words = await _repository.getKnownWordsList();
      final shouldShowQuiz = await QuizService.instance.shouldTriggerQuizAsync();
      if (mounted) {
        setState(() {
          _words = words;
          _showQuizCard = shouldShowQuiz;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      _isLoading = false;
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontSF,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
  );

  Widget _card(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _languageCard(BuildContext context, MapEntry<String, int> language) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preference = LanguageService().findByCode(language.key);
    final cefr = CefrLevel.fromWordCount(language.value);

    return InkWell(
      onTap: () {
        WeeklyConsistencyBadge.showConsistencyModal(
          context,
          words: _words,
          initialLanguage: language.key,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LanguageFlag(
                  countryCode: preference?.flagCode ?? language.key,
                  width: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizedLanguageName(context, language.key),
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cefr.badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cefr.code,
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cefr.badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${language.value}',
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.primary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Text(
              t('palavras conhecidas', 'known words'),
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _saved,
      AppLanguage.instance,
      AppThemeMode.instance,
    ]),
    builder: (context, _) {
      final tracks = _saved.tracks.take(20).toList();
      final summary = LearningSummary(_words, _saved.tracks);
      final colors = Theme.of(context).colorScheme;

      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                // Apple Large Title Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'DropLyric',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                      WeeklyConsistencyBadge(words: _words),
                    ],
                  ),
                ),

                // Minigame Desafio Rápido de Vocabulário
                if (_showQuizCard && _words.isNotEmpty)
                  HomeQuizCard(
                    words: _words,
                    onDismissed: () => setState(() => _showQuizCard = false),
                  ),

                // Recent tracks
                _heading(t('Músicas recentes', 'Recent songs')),
                if (tracks.isEmpty)
                  _card(
                    context,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.music_note_list,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              t('Nenhuma música recente', 'No recent songs'),
                              style: TextStyle(
                                fontFamily: AppTheme.fontSF,
                                color: colors.onSurfaceVariant,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) => TrackCard(
                        track: tracks[index],
                        onTap: () => _openPlayer(context, tracks[index]),
                      ),
                    ),
                  ),

                // Learning summary
                _heading(t('Progresso', 'Progress')),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_failed)
                  _card(
                    context,
                    Column(
                      children: [
                        Text(
                          t(
                            'Erro ao carregar progresso',
                            'Could not load progress',
                          ),
                          style: TextStyle(color: colors.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _load,
                          child: Text(
                            t('Tentar novamente', tr(context, "Try again")),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (summary.languages.isEmpty)
                    _card(
                      context,
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.chart_bar_alt_fill,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                t(
                                  'Seu progresso aparecerá aqui',
                                  'Your progress will appear here',
                                ),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontSF,
                                  color: colors.onSurfaceVariant,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: summary.languages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) =>
                            _languageCard(context, summary.languages[index]),
                      ),
                    ),

                  if (summary.artists.isNotEmpty) ...[
                    _heading(t('Top Artistas', 'Top Artists')),
                    _card(
                      context,
                      Column(
                        children: [
                          for (var i = 0; i < summary.artists.length; i++) ...[
                            if (i > 0)
                              Divider(
                                color: Theme.of(context).dividerColor,
                                height: 16,
                              ),
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontSF,
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    summary.artists[i].key,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontSF,
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${summary.artists[i].value} ${t('palavras', 'words')}',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _openPlayer(BuildContext context, TrackModel track) async {
    final lyricsOnly =
        !track.id.startsWith('spotify:') &&
        track.spotifyUrl == null &&
        track.previewAudioUrl == null;
    if (!lyricsOnly && SpotifySession.instance.connected) {
      try {
        track = await SpotifySession.instance.resolve(track);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  context,
                  "It was not possible to open the track. Try searching for it.",
                ),
              ),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final previous = AppRoutes.isTabRoute(AppRoutes.currentRoute.value)
        ? AppRoutes.currentRoute.value
        : AppRoutes.home;
    AppRoutes.currentRoute.value = AppRoutes.player;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.player),
          builder: (_) => PlayerPage(track: track, lyricsOnly: lyricsOnly),
        ),
      );
    } finally {
      AppRoutes.currentRoute.value = previous;
      AppRoutes.lastContentRoute = previous;
    }
  }
}

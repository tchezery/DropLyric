import '../core/services/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                            InkWell(
                              onTap: () => _showArtistSongsModal(
                                context,
                                summary.artists[i].key,
                                summary.artists[i].value,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
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
                                    const SizedBox(width: 6),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ),
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

  void _showArtistSongsModal(
    BuildContext context,
    String artistName,
    int totalWords,
  ) {
    HapticFeedback.lightImpact();
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPt = Localizations.localeOf(context).languageCode == 'pt';

    // Indexa faixas salvas por título para correspondência caso o artista na palavra esteja vazio
    final byTitle = <String, Set<String>>{};
    for (final track in _saved.tracks) {
      if (track.artist.trim().isEmpty) continue;
      byTitle
          .putIfAbsent(track.title.trim().toLowerCase(), () => {})
          .add(track.artist.trim());
    }

    // Filtra todas as palavras que pertencem a este artista
    final artistWords = _words.where((w) {
      var a = w.artistName?.trim();
      if (a == null || a.isEmpty) {
        final matches = byTitle[w.trackName?.trim().toLowerCase()];
        a = matches?.length == 1 ? matches!.single : null;
      }
      return a != null && a.toLowerCase() == artistName.toLowerCase();
    }).toList();

    // Agrupa as palavras pelas músicas de referência
    final wordsByTrack = <String, List<KnownWordModel>>{};
    for (final w in artistWords) {
      final title = (w.trackName != null && w.trackName!.trim().isNotEmpty)
          ? w.trackName!.trim()
          : (isPt ? 'Música não identificada' : 'Unidentified track');
      wordsByTrack.putIfAbsent(title, () => []).add(w);
    }

    final sortedTracks = wordsByTrack.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

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
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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

              // Header: Nome do Artista e total de palavras
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.music_mic,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artistName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontSF,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPt
                              ? '$totalWords ${totalWords == 1 ? "palavra aprendida" : "palavras aprendidas"} em ${sortedTracks.length} ${sortedTracks.length == 1 ? "música" : "músicas"}'
                              : '$totalWords ${totalWords == 1 ? "word learned" : "words learned"} across ${sortedTracks.length} ${sortedTracks.length == 1 ? "song" : "songs"}',
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
              const SizedBox(height: 18),

              // Lista de Músicas do Artista
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedTracks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = sortedTracks[index];
                    final songTitle = item.key;
                    final songWords = item.value;

                    // Busca se há TrackModel correspondente salvo na biblioteca
                    TrackModel? matchedTrack;
                    for (final t in _saved.tracks) {
                      if (t.title.trim().toLowerCase() == songTitle.toLowerCase()) {
                        matchedTrack = t;
                        break;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Ícone de música ou capa
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  borderRadius: BorderRadius.circular(10),
                                  image: matchedTrack?.albumArtUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(matchedTrack!.albumArtUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: matchedTrack?.albumArtUrl == null
                                    ? Icon(
                                        CupertinoIcons.music_note,
                                        size: 18,
                                        color: colors.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      songTitle,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontSF,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPt
                                          ? '${songWords.length} ${songWords.length == 1 ? "palavra" : "palavras"}'
                                          : '${songWords.length} ${songWords.length == 1 ? "word" : "words"}',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontSF,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (matchedTrack != null) ...[
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.play_circle_fill,
                                    color: Color(0xFF007AFF),
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _openPlayer(context, matchedTrack!);
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Chips com as palavras aprendidas nesta música
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: songWords.map((w) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  w.word,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Botão Fechar
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
                    isPt ? 'Fechar' : 'Close',
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

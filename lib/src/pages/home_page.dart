import '../core/services/app_strings.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/known_word_model.dart';
import '../core/models/learning_summary.dart';
import '../core/models/track_model.dart';
import '../core/repositories/known_words_repository.dart';
import '../core/services/language_service.dart';
import '../core/services/saved_tracks.dart';
import '../core/services/spotify_session.dart';
import '../widgets/spotify_access_gate.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/track_card.dart';
import '../widgets/language_flag.dart';
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
  PageRoute? _route;
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  void initState() {
    super.initState();
    _load();
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
    AppRoutes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _saved.ready;
      final words = await _repository.getKnownWordsList();
      if (mounted) {
        setState(() {
          _words = words;
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
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
    child: Text(
      text,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    ),
  );

  Widget _card(BuildContext context, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    ),
  );

  Widget _languageCard(BuildContext context, MapEntry<String, int> language) {
    final colors = Theme.of(context).colorScheme;
    final preference = LanguageService().findByCode(language.key);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LanguageFlag(
                countryCode: preference?.flagCode ?? language.key,
                width: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('Idioma', 'Language'),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            localizedLanguageName(context, language.key),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            t(
              '${language.value} palavras conhecidas',
              '${language.value} known words',
            ),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
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
      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                const Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 20, 6),
                  child: const Row(
                    children: const [
                      Expanded(
                        child: const Text(
                          'DropLyric',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      SpotifyConnectButton(compact: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    t(
                      'Seu vocabulário, uma música de cada vez.',
                      'Your vocabulary, one song at a time.',
                    ),
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ),
                _heading(t('Músicas recentes', 'Recent songs')),
                if (tracks.isEmpty)
                  _card(
                    context,
                    Text(
                      t(
                        'Abra uma música para começar seu histórico.',
                        'Open a song to start your history.',
                      ),
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  )
                else
                  SizedBox(
                    height:
                        230 + (MediaQuery.textScalerOf(context).scale(24) - 24),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) => TrackCard(
                        track: tracks[index],
                        onTap: () => _openPlayer(context, tracks[index]),
                      ),
                    ),
                  ),
                _heading(t('Seu aprendizado', 'Your learning')),
                if (_loading)
                  const Center(child: const CircularProgressIndicator())
                else if (_failed)
                  _card(
                    context,
                    Column(
                      children: [
                        Text(
                          t(
                            'Não foi possível carregar seu progresso.',
                            'Could not load your progress.',
                          ),
                        ),
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
                      Text(
                        t(
                          'Salve palavras nas letras para acompanhar seu progresso.',
                          'Save words in lyrics to track your progress.',
                        ),
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: summary.languages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) =>
                            _languageCard(context, summary.languages[index]),
                      ),
                    ),
                  _heading(t('Top 3 artistas', 'Top 3 artists')),
                  _card(
                    context,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            'Quem mais ensinou palavras a você',
                            'Who taught you the most words',
                          ),
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        if (summary.artists.isEmpty)
                          Text(
                            t(
                              'Salve palavras nas músicas para descobrir seus artistas aqui.',
                              'Save words from songs to discover your artists here.',
                            ),
                          ),
                        for (var i = 0; i < summary.artists.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.yellow.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppTheme.yellow,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    summary.artists[i].key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  t(
                                    '${summary.artists[i].value} palavras',
                                    '${summary.artists[i].value} words',
                                  ),
                                  style: const TextStyle(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
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
    final previous = AppRoutes.currentRoute.value;
    AppRoutes.currentRoute.value = AppRoutes.player;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.player),
        builder: (_) => SpotifyAccessGate(
          child: PlayerPage(track: track, lyricsOnly: lyricsOnly),
        ),
      ),
    );
    AppRoutes.currentRoute.value = previous;
  }
}

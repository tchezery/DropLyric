import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/saved_tracks.dart';
import '../core/services/spotify_service.dart';
import '../core/services/spotify_session.dart';
import '../widgets/lyrics_search_panel.dart';
import '../widgets/spotify_icon.dart';
import '../widgets/track_card.dart';
import '../widgets/youtube_search_panel.dart';
import 'player_page.dart';

class RemoteMusicPage extends StatefulWidget {
  const RemoteMusicPage({super.key});
  @override
  State<RemoteMusicPage> createState() => _RemoteMusicPageState();
}

class _RemoteMusicPageState extends State<RemoteMusicPage> {
  final _input = TextEditingController();
  final _session = SpotifySession.instance;
  final _saved = SavedTracks.instance;
  String? _error;
  bool get _pt => Localizations.localeOf(context).languageCode == 'pt';
  String t(String pt, String en) => _pt ? pt : en;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
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

  Future<void> _open(TrackModel track, {bool follow = false}) async {
    final previous = AppRoutes.currentRoute.value;
    AppRoutes.currentRoute.value = AppRoutes.player;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.player),
        builder: (_) => PlayerPage(track: track, followCurrent: follow),
      ),
    );
    AppRoutes.currentRoute.value = previous;
  }

  Future<void> _searchOrOpenSpotify() async {
    final text = _input.text.trim();
    if (text.isEmpty) {
      final appUri = Uri.parse('spotify:');
      final webUri = Uri.parse('https://open.spotify.com');
      try {
        if (!await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final uri = SpotifyService.playbackUri(text);
    if (uri != null) {
      setState(() => _error = null);
      _open(
        TrackModel(
          id: uri,
          title: '',
          artist: '',
          album: '',
          previewAudioUrl: uri,
        ),
      );
      return;
    }

    final appSearchUri =
        Uri.parse('spotify:search:${Uri.encodeComponent(text)}');
    final webSearchUri =
        Uri.parse('https://open.spotify.com/search/${Uri.encodeComponent(text)}');
    try {
      if (!await launchUrl(appSearchUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(webSearchUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webSearchUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                t('Não foi possível abrir o Spotify', 'Could not open Spotify'),
          );
        }
      }
    }
  }

  Widget _groupedCard(BuildContext context, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
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
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _trackTile(TrackModel track) {
    final colors = Theme.of(context).colorScheme;
    final isFav = _saved.isFavorite(track.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: AlbumArtImage(
        track: track,
        size: 44,
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text(
        track.title,
        style: TextStyle(
          fontFamily: AppTheme.fontSF,
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        style: TextStyle(
          fontFamily: AppTheme.fontSF,
          color: colors.onSurfaceVariant,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _open(track),
      trailing: IconButton(
        icon: Icon(
          isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          color: isFav ? AppTheme.appleRed : colors.onSurfaceVariant.withValues(alpha: 0.6),
          size: 20,
        ),
        onPressed: () async {
          try {
            await _saved.toggleFavorite(track);
          } catch (_) {}
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([_saved, _session]),
        builder: (context, _) {
          final current = _session.currentTrack;
          final favorites = _saved.tracks
              .where((track) => _saved.isFavorite(track.id))
              .toList();
          final history = _saved.tracks;
          final colors = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // Large Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Text(
                  t('Buscar', 'Search'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontSF,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
              ),

              // 1. Pesquisar no YouTube / YouTube Music (Opção principal)
              _heading(t('Pesquisar no YouTube', 'Search on YouTube')),
              const YouTubeSearchPanel(),

              const SizedBox(height: 12),

              // 2. Pesquisar no Spotify (apenas se conectado)
              if (_session.connected) ...[
                _heading(t('Pesquisar no Spotify', 'Search on Spotify')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _searchOrOpenSpotify(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: SpotifyIcon(size: 20),
                      ),
                      hintText: t(
                        'Buscar no Spotify ou colar link…',
                        'Search on Spotify or paste link…',
                      ),
                      suffixIcon: IconButton(
                        tooltip: t('Abrir no Spotify', 'Open in Spotify'),
                        onPressed: _searchOrOpenSpotify,
                        icon: const Icon(
                          CupertinoIcons.arrow_right_circle_fill,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontFamily: AppTheme.fontSF,
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // 3. Pesquisar apenas a letra
              _heading(t('Pesquisar apenas a letra', 'Search lyrics only')),
              const LyricsSearchPanel(),

              const SizedBox(height: 16),

              // Now Playing
              if (current != null && _session.state['ready'] == true) ...[
                _heading(t('Tocando agora', 'Now Playing')),
                _groupedCard(
                  context,
                  [
                    ListTile(
                      leading: AlbumArtImage(
                        track: current,
                        size: 44,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(
                        current.title,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontSF,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        current.artist,
                        style: TextStyle(
                          fontFamily: AppTheme.fontSF,
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Icon(
                        CupertinoIcons.chevron_right,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      onTap: () => _open(current, follow: true),
                    ),
                  ],
                ),
              ],

              // Favorites
              if (favorites.isNotEmpty) ...[
                _heading(t('Favoritos', 'Favorites')),
                _groupedCard(
                  context,
                  [
                    for (var i = 0; i < favorites.length; i++) ...[
                      if (i > 0) Divider(color: Theme.of(context).dividerColor, height: 1),
                      _trackTile(favorites[i]),
                    ],
                  ],
                ),
              ],

              // History
              if (history.isNotEmpty) ...[
                _heading(t('Histórico', 'History')),
                _groupedCard(
                  context,
                  [
                    for (var i = 0; i < history.length; i++) ...[
                      if (i > 0) Divider(color: Theme.of(context).dividerColor, height: 1),
                      _trackTile(history[i]),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

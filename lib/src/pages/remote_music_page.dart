import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../core/models/track_model.dart';
import '../core/services/saved_tracks.dart';
import '../core/services/spotify_service.dart';
import '../core/services/spotify_session.dart';
import '../widgets/spotify_connect_button.dart';
import '../widgets/lyrics_search_panel.dart';
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
  List<Map<String, dynamic>> _content = [];
  final List<({String id, String title})> _path = [];
  bool _loading = false;
  String? _error;
  bool get _pt => Localizations.localeOf(context).languageCode == 'pt';
  String t(String pt, String en) => _pt ? pt : en;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _browse({String? id, String? title, bool back = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final nextPath = [..._path];
    if (back && nextPath.isNotEmpty) {
      nextPath.removeLast();
    } else if (id != null) {
      nextPath.add((id: id, title: title ?? ''));
    }
    try {
      final items = await _session.content(
        nextPath.isEmpty ? '' : nextPath.last.id,
      );
      if (!mounted) return;
      setState(() {
        _path
          ..clear()
          ..addAll(nextPath);
        _content = items;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t(
            'Não foi possível carregar. Conecte ao Spotify e tente novamente.',
            'Could not load content. Connect to Spotify and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  void _openLink() {
    final uri = SpotifyService.playbackUri(_input.text.trim());
    if (uri == null) {
      setState(
        () => _error = t(
          'Cole um link completo open.spotify.com/track/… ou uma URI spotify:track:… de uma música.',
          'Paste a full open.spotify.com/track/… link or spotify:track:… URI for a song.',
        ),
      );
      return;
    }
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
  }

  Future<void> _playContent(Map<String, dynamic> item) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _session.command('playContent', item['id'] as String);
      // Player events provide the actual track metadata, including for playlists.
      if (!mounted) return;
      final current = _session.currentTrack;
      await _open(
        current ?? const TrackModel(id: '', title: '', artist: '', album: ''),
        follow: true,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t(
            'Não foi possível tocar. Confira a conexão com o Spotify.',
            'Could not play. Check your Spotify connection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _track(TrackModel track) => ListTile(
    leading: const Icon(Icons.music_note),
    title: Text(track.title),
    subtitle: Text(track.artist),
    onTap: () => _open(track),
    trailing: IconButton(
      tooltip: t('Favorito no DropLyric', 'DropLyric favorite'),
      icon: Icon(
        _saved.isFavorite(track.id) ? Icons.favorite : Icons.favorite_border,
      ),
      onPressed: () async {
        try {
          await _saved.toggleFavorite(track);
        } catch (_) {
          if (mounted) {
            setState(
              () => _error = t(
                'Não foi possível salvar o favorito.',
                'Could not save favorite.',
              ),
            );
          }
        }
      },
    ),
  );

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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Text(
                t('Escolher música', 'Choose music'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const LyricsSearchPanel(),
              const SizedBox(height: 24),
              const SpotifyConnectButton(),
              Text(
                t(
                  'Cole o link de uma música ou escolha nas listas abaixo. A música toca no app Spotify.',
                  'Paste a song link or choose from the lists below. Music plays in the Spotify app.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                onSubmitted: (_) => _openLink(),
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  labelText: t(
                    'Link da música no Spotify',
                    'Spotify song link',
                  ),
                  hintText: 'https://open.spotify.com/track/…',
                  suffixIcon: IconButton(
                    tooltip: t('Tocar música', 'Play song'),
                    onPressed: _openLink,
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (current != null && _session.state['ready'] == true) ...[
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(t('Acompanhar agora', 'Follow now')),
                  subtitle: Text('${current.title} • ${current.artist}'),
                  onTap: () => _open(current, follow: true),
                ),
              ],
              const SizedBox(height: 20),
              if (defaultTargetPlatform == TargetPlatform.macOS)
                Text(
                  t(
                    'No Mac, escolha uma música pelo link ou no app Spotify. Depois use Acompanhar agora.',
                    'On Mac, choose a song by link or in the Spotify app, then use Follow now.',
                  ),
                ),
              if (defaultTargetPlatform != TargetPlatform.macOS) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('Do Spotify', 'From Spotify'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : () => _browse(),
                      child: Text(t('Carregar', 'Load')),
                    ),
                  ],
                ),
                Text(
                  t(
                    'Recomendações e conteúdos disponíveis para sua conta. Não é uma busca no catálogo.',
                    'Recommendations and content available to your account. This is not a catalog search.',
                  ),
                ),
                if (_path.isNotEmpty)
                  TextButton.icon(
                    onPressed: _loading ? null : () => _browse(back: true),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(_path.last.title),
                  ),
                if (_loading) const LinearProgressIndicator(),
                for (final item in _content)
                  ListTile(
                    title: Text(item['title'] as String? ?? ''),
                    subtitle: Text(item['subtitle'] as String? ?? ''),
                    onTap: _loading
                        ? null
                        : item['children'] == true
                        ? () => _browse(
                            id: item['id'] as String,
                            title: item['title'] as String?,
                          )
                        : item['playable'] == true
                        ? () => _playContent(item)
                        : null,
                    trailing: item['playable'] == true
                        ? IconButton(
                            tooltip: t('Tocar', 'Play'),
                            onPressed: _loading
                                ? null
                                : () => _playContent(item),
                            icon: const Icon(Icons.play_arrow),
                          )
                        : item['children'] == true
                        ? const Icon(Icons.chevron_right)
                        : null,
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                t('Favoritos do DropLyric', 'DropLyric favorites'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (favorites.isEmpty)
                Text(
                  t(
                    'Toque no coração de uma música do histórico para salvar aqui.',
                    'Tap the heart on a song in history to save it here.',
                  ),
                ),
              ...favorites.map(_track),
              const SizedBox(height: 24),
              Text(
                t('Histórico neste aparelho', 'History on this device'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_saved.tracks.isEmpty)
                Text(
                  t(
                    'As músicas acompanhadas aparecerão aqui.',
                    'Songs you follow will appear here.',
                  ),
                ),
              ..._saved.tracks.map(_track),
            ],
          );
        },
      ),
    ),
  );
}

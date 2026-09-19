import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../core/services/lyrics_service.dart';
import '../core/services/spotify_service.dart';
import '../pages/player_page.dart';
import 'spotify_icon.dart';

class LyricsSearchPanel extends StatefulWidget {
  const LyricsSearchPanel({super.key, this.service});
  final LyricsService? service;
  @override
  State<LyricsSearchPanel> createState() => _LyricsSearchPanelState();
}

class _LyricsSearchPanelState extends State<LyricsSearchPanel> {
  final _query = TextEditingController();
  late final LyricsService _service = widget.service ?? LyricsService();
  List<LyricsSearchEntry> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _generation = 0;
  String t(String pt, String en) => Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    final generation = ++_generation;
    setState(() {
      _error = null;
      _results = [];
      _searched = false;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    try {
      final results = await _service.search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = t(
            'Não foi possível buscar no LRCLIB. Tente novamente.',
            'Could not search LRCLIB. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _select(LyricsSearchEntry entry) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LyricsSelection(entry: entry),
    );
    if (!mounted || choice == null) return;
    final readOnly = choice == 'read';
    final track = readOnly
        ? entry.track
        : entry.track.copyWith(id: choice, previewAudioUrl: choice);
    final previous = AppRoutes.currentRoute.value;
    AppRoutes.currentRoute.value = AppRoutes.player;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.player),
        builder: (_) => PlayerPage(
          track: track,
          lyricsOnly: readOnly,
          initialLyrics: readOnly ? entry.lyrics : null,
        ),
      ),
    );
    AppRoutes.currentRoute.value = previous;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        onChanged: (_) {
          if (_loading || _searched || _error != null) {
            ++_generation;
            setState(() {
              _loading = false;
              _searched = false;
              _results = [];
              _error = null;
            });
          }
        },
        decoration: InputDecoration(
          labelText: t('Buscar música ou artista', 'Search song or artist'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: t('Buscar', 'Search'),
            onPressed: _search,
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        t(
          'Procure pelaa pela letra da sua música.',
          'Search if we have the lyrics for your song.',
        ),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_searched && _results.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            t(
              'Nenhuma música encontrada. Tente incluir o artista.',
              'No songs found. Try including the artist.',
            ),
          ),
        ),
      for (final entry in _results)
        ListTile(
          title: Text(entry.track.title),
          subtitle: Text(
            [
              entry.track.artist,
              if (entry.track.album.isNotEmpty) entry.track.album,
              if (entry.track.duration != null)
                '${entry.track.duration!.floor() ~/ 60}:${(entry.track.duration!.floor() % 60).toString().padLeft(2, '0')}',
              entry.instrumental
                  ? t('Instrumental', 'Instrumental')
                  : entry.lyrics?.isSynced == true
                  ? t('Letra sincronizada', 'Synced lyrics')
                  : entry.lyrics != null
                  ? t('Letra disponível', 'Lyrics available')
                  : t('Sem letra', 'No lyrics'),
            ].join(' • '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _select(entry),
        ),
    ],
  );
}

class _LyricsSelection extends StatefulWidget {
  const _LyricsSelection({required this.entry});
  final LyricsSearchEntry entry;
  @override
  State<_LyricsSelection> createState() => _LyricsSelectionState();
}

class _LyricsSelectionState extends State<_LyricsSelection> {
  final _link = TextEditingController();
  String? _error;
  String t(String pt, String en) => Localizations.localeOf(context).languageCode == 'pt' ? pt : en;
  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _findSpotify() async {
    final query = '${widget.entry.track.title} ${widget.entry.track.artist}';
    try {
      final opened = await launchUrl(
        Uri(
          scheme: 'https',
          host: 'open.spotify.com',
          pathSegments: ['search', query],
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Could not open Spotify');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t(
            'Não foi possível abrir o Spotify.',
            'Could not open Spotify.',
          ),
        );
      }
    }
  }

  void _play() {
    final uri = SpotifyService.playbackUri(_link.text.trim());
    if (uri == null) {
      setState(
        () => _error = t(
          'Cole o link completo de uma faixa do Spotify.',
          'Paste a full Spotify song link.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.entry.track.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(widget.entry.track.artist),
          const SizedBox(height: 16),
          if (widget.entry.lyrics != null)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('read'),
              icon: const Icon(Icons.menu_book),
              label: Text(t('Abrir letra', 'Open lyrics')),
            )
          else
            Text(
              t(
                'Este registro não tem letra disponível.',
                'This record has no lyrics available.',
              ),
            ),
          const SizedBox(height: 16),
          Text(
            t(
              'Para ouvir, escolha esta versão no Spotify. O LRCLIB fornece a letra, mas não o link de reprodução.',
              'To listen, choose this version in Spotify. LRCLIB provides lyrics, but not a playback link.',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _findSpotify,
            icon: const SpotifyIcon(size: 18),
            label: Text(t('Buscar no Spotify', 'Search in Spotify')),
          ),
          TextField(
            controller: _link,
            onSubmitted: (_) => _play(),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: SpotifyIcon(size: 20),
              ),
              labelText: t('Link da faixa no Spotify', 'Spotify song link'),
              hintText: 'https://open.spotify.com/track/…',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _play,
            child: Text(t('Tocar pelo link', 'Play using link')),
          ),
        ],
      ),
    ),
  );
}

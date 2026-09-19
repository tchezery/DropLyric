import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
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
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

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
          () => _error = t('Erro ao buscar letras', 'Error searching lyrics'),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (text) {
              if (text.isEmpty && (_searched || _results.isNotEmpty)) {
                setState(() {
                  _results = [];
                  _searched = false;
                });
              }
            },
            decoration: InputDecoration(
              hintText: t('Buscar letra ou música…', 'Search lyrics or song…'),
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
              suffixIcon: _query.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                      onPressed: () {
                        _query.clear();
                        setState(() {
                          _results = [];
                          _searched = false;
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(CupertinoIcons.arrow_right_circle_fill, size: 28),
                      onPressed: _search,
                    ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontFamily: AppTheme.fontSF,
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          if (_searched && _results.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  t('Nenhum resultado encontrado', 'No results found'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _results.length; i++) ...[
                      if (i > 0) Divider(color: Theme.of(context).dividerColor, height: 1),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          _results[i].track.title,
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
                          _results[i].track.artist,
                          style: TextStyle(
                            fontFamily: AppTheme.fontSF,
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_results[i].lyrics?.isSynced == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.appleBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t('SYNC', 'SYNC'),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontSF,
                                    color: AppTheme.appleBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              CupertinoIcons.chevron_right,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                              size: 16,
                            ),
                          ],
                        ),
                        onTap: () => _select(_results[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
  String t(String pt, String en) =>
      Localizations.localeOf(context).languageCode == 'pt' ? pt : en;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _findSpotify() async {
    final query = '${widget.entry.track.title} ${widget.entry.track.artist}';
    try {
      await launchUrl(
        Uri(
          scheme: 'https',
          host: 'open.spotify.com',
          pathSegments: ['search', query],
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _play() {
    final uri = SpotifyService.playbackUri(_link.text.trim());
    if (uri == null) {
      setState(
        () => _error = t('Cole um link do Spotify válido', 'Paste a valid Spotify link'),
      );
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.entry.track.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontSF,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.entry.track.artist,
            style: TextStyle(
              fontFamily: AppTheme.fontSF,
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.menu_book),
            onPressed: () => Navigator.of(context).pop('read'),
            label: Text(t('Ler letra', 'Read lyrics')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            onPressed: _findSpotify,
            label: Text(t('Buscar no Spotify', 'Search in Spotify')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            onSubmitted: (_) => _play(),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: SpotifyIcon(size: 20),
              ),
              hintText: t('Link da faixa no Spotify…', 'Spotify track link…'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
          FilledButton(
            onPressed: _play,
            child: Text(t('Tocar pelo link', 'Play using link')),
          ),
        ],
      ),
    );
  }
}

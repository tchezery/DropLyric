import '../core/services/app_strings.dart';
import 'package:flutter/foundation.dart';

import 'remote_music_page.dart';
import '../widgets/spotify_access_gate.dart';

import 'package:flutter/cupertino.dart';

import '../widgets/spotify_connect_button.dart';
import '../core/services/spotify_session.dart';

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/spotify_service.dart';
import '../widgets/track_card.dart';
import 'player_page.dart';

/// Busca de músicas no estilo Spotify.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SpotifyService _spotifyService = SpotifyService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<TrackModel> _results = [];
  bool _loading = false;
  bool _searched = false;

  // Categorias de gênero/idioma para o estado inicial (estilo Spotify)
  static const _categories = [
    ('English', CupertinoIcons.globe, Color(0xFFF4E9C5)),
    ('Español', CupertinoIcons.globe, Color(0xFFF2DECF)),
    ('Français', CupertinoIcons.globe, Color(0xFFE0E7EB)),
    ('Português', CupertinoIcons.globe, Color(0xFFE2E8D7)),
    ('Rock', CupertinoIcons.music_albums, Color(0xFFE9DFF0)),
    ('Jazz', CupertinoIcons.music_note, Color(0xFFEDE2D1)),
    ('Pop', CupertinoIcons.headphones, Color(0xFFDFE9E6)),
    ('Hip-Hop', CupertinoIcons.music_note_list, Color(0xFFF0DDE0)),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = false;
    });
    SearchResult result;
    try {
      result = await _spotifyService.searchTracks(query);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, "Spotify search failed. Check your connection and try again."),
          ),
        ),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _results = result.tracks;
        _searched = true;
      });
    }
  }

  Future<void> _openPlayer(TrackModel track) async {
    if (SpotifySession.instance.connected) {
      try {
        track = await SpotifySession.instance.resolve(track);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(context, "Could not open the track on Spotify. Try searching."),
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
    }

    final prevRoute = AppRoutes.currentRoute.value;
    AppRoutes.currentRoute.value = AppRoutes.player;
    await Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: AppRoutes.player),
        pageBuilder: (ctx, animation, _) =>
            SpotifyAccessGate(child: PlayerPage(track: track)),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (ctx, animation, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
    AppRoutes.currentRoute.value = prevRoute;
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const RemoteMusicPage();
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';
    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SpotifyConnectButton(),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                isPortuguese ? 'Buscar' : 'Search',
                style: const TextStyle(
                  color: AppTheme.spotifyWhite,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Search bar estilo Spotify (branca, arredondada)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.separator,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppTheme.yellow,
                  decoration: InputDecoration(
                    hintText: isPortuguese
                        ? 'Que música você quer aprender?'
                        : 'What track do you want to learn?',
                    hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 14),
                    border: InputBorder.none,
                    filled: false,
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      color: AppTheme.ink,
                      size: 22,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              CupertinoIcons.clear,
                              color: AppTheme.ink,
                              size: 18,
                            ),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = [];
                                _searched = false;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _search,
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';
    if (_loading) {
      return const Center(
        child: const CircularProgressIndicator(color: AppTheme.spotifyGreen),
      );
    }

    if (_searched && _results.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _results.length,
        itemBuilder: (ctx, i) => TrackListTile(
          track: _results[i],
          onTap: () => _openPlayer(_results[i]),
        ),
      );
    }

    if (_searched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.search,
              size: 52,
              color: AppTheme.spotifyMediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, "No tracks found."),
              style: const TextStyle(color: AppTheme.spotifyLightGray),
            ),
          ],
        ),
      );
    }

    // Estado inicial — grid de categorias estilo Spotify
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            isPortuguese ? 'Explorar categorias' : 'Explore categories',
            style: const TextStyle(
              color: AppTheme.spotifyWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.1,
            ),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final (label, icon, color) = _categories[i];
              return _CategoryCard(
                label: switch (label) {
                  'English' => localizedLanguageName(context, 'en'),
                  'Español' => localizedLanguageName(context, 'es'),
                  'Français' => localizedLanguageName(context, 'fr'),
                  'Português' => localizedLanguageName(context, 'pt'),
                  _ => label,
                },
                icon: icon,
                color: color,
                onTap: () {
                  _controller.text = label;
                  _search(label);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.spotifyWhite, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.spotifyWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import '../core/services/app_strings.dart';
import 'package:flutter/foundation.dart';

import 'remote_music_page.dart';

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
            PlayerPage(track: track),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';
    final primaryTextColor = isDark ? AppTheme.labelDark : AppTheme.labelLight;
    final secondaryTextColor = isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;
    final searchBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SpotifyConnectButton(),
            // Large Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                isPortuguese ? 'Buscar' : 'Search',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  color: primaryTextColor,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ),

            // iOS Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    color: primaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppTheme.appleBlue,
                  decoration: InputDecoration(
                    hintText: isPortuguese
                        ? 'Artistas, músicas ou letras'
                        : 'Artists, tracks or lyrics',
                    hintStyle: TextStyle(
                      fontFamily: '.SF Pro Text',
                      color: secondaryTextColor,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: secondaryTextColor,
                      size: 20,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = [];
                                _searched = false;
                              });
                            },
                            child: Icon(
                              CupertinoIcons.clear_circled_solid,
                              color: secondaryTextColor,
                              size: 18,
                            ),
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

            const SizedBox(height: 18),
            Expanded(child: _buildBody(isDark, primaryTextColor, secondaryTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color primaryTextColor, Color secondaryTextColor) {
    final isPortuguese = Localizations.localeOf(context).languageCode == 'pt';
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }

    if (_searched && _results.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 120, top: 4),
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
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: secondaryTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, "No tracks found."),
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                color: secondaryTextColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    // Initial State — Apple Inset Category Cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            isPortuguese ? 'Categorias' : 'Categories',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              color: primaryTextColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
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
                isDark: isDark,
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
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);
    final textColor = isDark
        ? AppTheme.labelDark
        : AppTheme.labelLight;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.35 : 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark ? AppTheme.white : const Color(0xFF1C1C1E),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

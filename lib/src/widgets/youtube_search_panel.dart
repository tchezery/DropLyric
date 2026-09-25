import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/app_strings.dart';
import '../core/services/youtube_service.dart';
import '../pages/player_page.dart';

class YouTubeSearchPanel extends StatefulWidget {
  const YouTubeSearchPanel({super.key});

  @override
  State<YouTubeSearchPanel> createState() => _YouTubeSearchPanelState();
}

class _YouTubeSearchPanelState extends State<YouTubeSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final YouTubeService _ytService = YouTubeService.instance;

  List<TrackModel> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _ytService.search(clean);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = tr(context, "No YouTube tracks found.");
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = tr(context, "Search failed. Check your connection.");
        });
      }
    }
  }

  void _openPlayer(TrackModel track) async {
    final previous = AppRoutes.isTabRoute(AppRoutes.currentRoute.value)
        ? AppRoutes.currentRoute.value
        : AppRoutes.search;
    AppRoutes.currentRoute.value = AppRoutes.player;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.player),
          builder: (_) => PlayerPage(
            track: track,
            playlist: _results.isNotEmpty ? _results : [track],
            initialIndex: _results.indexWhere((t) => t.id == track.id),
          ),
        ),
      );
    } finally {
      AppRoutes.currentRoute.value = previous;
      AppRoutes.lastContentRoute = previous;
    }
  }

  String _fmtDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            onSubmitted: _performSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  CupertinoIcons.play_rectangle_fill,
                  color: Color(0xFFFF0000),
                  size: 22,
                ),
              ),
              hintText: tr(
                context,
                "Search song on YouTube or paste link…",
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_errorMessage != null && !_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: AppTheme.fontSF,
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        if (_results.isNotEmpty && !_isLoading) ...[
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _results.length,
            separatorBuilder: (_, _) => Divider(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final track = _results[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: track.albumArtUrl != null
                      ? Image.network(
                          track.albumArtUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: colors.surfaceContainerHighest,
                            child: const Icon(
                              CupertinoIcons.music_note,
                              size: 22,
                            ),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: colors.surfaceContainerHighest,
                          child: const Icon(
                            CupertinoIcons.music_note,
                            size: 22,
                          ),
                        ),
                ),
                title: Text(
                  track.title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.artist,
                  style: TextStyle(
                    fontFamily: AppTheme.fontSF,
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track.duration != null)
                      Text(
                        _fmtDuration(track.duration),
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        size: 14,
                        color: AppTheme.spotifyGreen,
                      ),
                    ),
                  ],
                ),
                onTap: () => _openPlayer(track),
              );
            },
          ),
        ],
      ],
    );
  }
}

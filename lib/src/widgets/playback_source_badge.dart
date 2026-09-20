import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/app_strings.dart';
import 'spotify_icon.dart';

/// Badge visual elegante indicando a fonte de reprodução (Spotify ou YouTube).
class PlaybackSourceBadge extends StatelessWidget {
  final TrackModel? track;
  final bool isYouTube;
  final bool isSpotify;
  final bool compact;
  final double fontSize;
  final double iconSize;

  const PlaybackSourceBadge({
    super.key,
    this.track,
    this.isYouTube = false,
    this.isSpotify = false,
    this.compact = false,
    this.fontSize = 11,
    this.iconSize = 12,
  });

  bool get _yt => isYouTube || (track?.isYouTube ?? false);
  bool get _sp => isSpotify || (track?.isSpotify ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_yt && !_sp) return const SizedBox.shrink();

    final color = _yt ? Colors.redAccent : AppTheme.spotifyGreen;
    final label = _yt ? 'YouTube' : 'Spotify';
    final tooltipText = _yt
        ? tr(context, "Playing via YouTube")
        : tr(context, "Playing via Spotify");

    if (compact) {
      return Tooltip(
        message: tooltipText,
        child: Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: _yt
              ? Icon(
                  CupertinoIcons.play_rectangle_fill,
                  size: iconSize,
                  color: Colors.redAccent,
                )
              : SpotifyIcon(size: iconSize),
        ),
      );
    }

    return Tooltip(
      message: tooltipText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _yt
                ? Icon(
                    CupertinoIcons.play_rectangle_fill,
                    size: iconSize,
                    color: Colors.redAccent,
                  )
                : SpotifyIcon(size: iconSize),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

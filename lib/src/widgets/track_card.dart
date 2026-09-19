import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/models/track_model.dart';
import '../core/services/spotify_cover_service.dart';

class TrackCard extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onTap;

  const TrackCard({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album artwork with Apple squircle top corners
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: AlbumArtImage(
                track: track,
                url: track.albumArtUrl,
                size: 156,
              ),
            ),

            // Track info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      color: colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontFamily: AppTheme.fontSF,
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal Apple Music-style list tile for track results and lists.
class TrackListTile extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onTap;

  const TrackListTile({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AlbumArtImage(
          track: track,
          url: track.albumArtUrl,
          size: 50,
        ),
      ),
      title: Text(
        track.title,
        style: TextStyle(
          fontFamily: AppTheme.fontSF,
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: -0.2,
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
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        size: 16,
      ),
    );
  }
}

class AlbumArtImage extends StatefulWidget {
  final String? url;
  final TrackModel? track;
  final String? spotifyUri;
  final double size;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AlbumArtImage({
    super.key,
    this.url,
    this.track,
    this.spotifyUri,
    this.size = 50,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<AlbumArtImage> createState() => _AlbumArtImageState();
}

class _AlbumArtImageState extends State<AlbumArtImage> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant AlbumArtImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.track?.id != widget.track?.id ||
        oldWidget.spotifyUri != widget.spotifyUri) {
      _resolveUrl();
    }
  }

  Future<void> _resolveUrl() async {
    if (widget.url != null && widget.url!.isNotEmpty) {
      setState(() => _resolvedUrl = widget.url);
      return;
    }

    final cached = await SpotifyCoverService.instance.getCoverUrl(
      track: widget.track,
      spotifyUriOrUrl: widget.spotifyUri,
    );

    if (mounted) {
      setState(() {
        _resolvedUrl = cached;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;

    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      Widget image = Image.network(
        _resolvedUrl!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _placeholder(context, w, h);
        },
        errorBuilder: (_, _, _) => _placeholder(context, w, h),
      );

      if (widget.borderRadius != null) {
        image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
      }
      return image;
    }

    Widget placeholder = _placeholder(context, w, h);
    if (widget.borderRadius != null) {
      placeholder = ClipRRect(borderRadius: widget.borderRadius!, child: placeholder);
    }
    return placeholder;
  }

  Widget _placeholder(BuildContext context, double w, double h) => Container(
    width: w,
    height: h,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        CupertinoIcons.music_note,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: (w < h ? w : h) * 0.4,
      ),
    ),
  );
}

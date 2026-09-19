import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../core/models/track_model.dart';

class TrackCard extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onTap;

  const TrackCard({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          color: AppTheme.spotifyDarkCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa do álbum
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: _AlbumArt(url: track.albumArtUrl, size: 152),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: AppTheme.spotifyWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    style: const TextStyle(
                      color: AppTheme.spotifyLightGray,
                      fontSize: 11,
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

/// Card horizontal (lista) estilo Spotify para resultados de busca.
class TrackListTile extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onTap;

  const TrackListTile({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _AlbumArt(url: track.albumArtUrl, size: 48),
      ),
      title: Text(
        track.title,
        style: const TextStyle(
          color: AppTheme.spotifyWhite,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        style: const TextStyle(color: AppTheme.spotifyLightGray, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(
          CupertinoIcons.ellipsis_vertical,
          color: AppTheme.spotifyLightGray,
          size: 20,
        ),
        onPressed: () {},
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String? url;
  final double size;

  const _AlbumArt({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: AppTheme.spotifyMediumGray,
    child: const Center(
      child: Icon(
        CupertinoIcons.music_note,
        color: AppTheme.spotifyLightGray,
        size: 28,
      ),
    ),
  );
}

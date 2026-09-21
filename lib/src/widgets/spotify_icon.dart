import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';

/// Ícone oficial do Spotify carregado via SVG do assets.
class SpotifyIcon extends StatelessWidget {
  const SpotifyIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  /// Tamanho do ícone (largura e altura).
  final double size;

  /// Cor opcional do ícone. Se null, preserva o verde oficial (#1DB954).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/spotify.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : const ColorFilter.mode(AppTheme.spotifyGreen, BlendMode.srcIn),
    );
  }
}

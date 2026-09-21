import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/track_model.dart';

/// Serviço responsável por obter a capa oficial do álbum via Spotify oEmbed público (sem autenticação).
class SpotifyCoverService {
  SpotifyCoverService._();
  static final SpotifyCoverService instance = SpotifyCoverService._();

  // Cache em memória de ID/URI -> URL da Imagem
  final Map<String, String> _cache = {};
  final Map<String, Future<String?>> _inFlight = {};

  /// Extrai o ID do Spotify a partir de uma URI (spotify:track:XXX) ou URL web (open.spotify.com/track/XXX).
  static String? extractSpotifyId(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final clean = source.trim();

    // Formato URI: spotify:track:7qiZfU4dY1lWllzX7mPBI3
    final uriMatch = RegExp(r'spotify:track:([a-zA-Z0-9]{22})').firstMatch(clean);
    if (uriMatch != null) return uriMatch.group(1);

    // Formato URL: https://open.spotify.com/track/7qiZfU4dY1lWllzX7mPBI3 ou /intl-pt/track/7qiZfU4dY1lWllzX7mPBI3
    final urlMatch = RegExp(r'open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?track/([a-zA-Z0-9]{22})').firstMatch(clean);
    if (urlMatch != null) return urlMatch.group(1);

    // ID cru de 22 caracteres
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) return clean;

    return null;
  }

  /// Retorna a URL da imagem de capa via Spotify oEmbed.
  Future<String?> getCoverUrl({
    String? trackId,
    String? spotifyUriOrUrl,
    TrackModel? track,
  }) async {
    // 1. Se o track já possuir a URL da capa preenchida, retorna ela
    if (track?.albumArtUrl != null && track!.albumArtUrl!.isNotEmpty) {
      return track.albumArtUrl;
    }

    // 2. Extrai o ID
    final id = extractSpotifyId(trackId) ??
        extractSpotifyId(spotifyUriOrUrl) ??
        extractSpotifyId(track?.id) ??
        extractSpotifyId(track?.spotifyUrl) ??
        extractSpotifyId(track?.previewAudioUrl);

    if (id == null) return null;

    // 3. Verifica se já está em cache
    if (_cache.containsKey(id)) {
      return _cache[id];
    }

    // 4. Se já há uma requisição em andamento para esse mesmo ID, reutiliza o Future
    if (_inFlight.containsKey(id)) {
      return _inFlight[id];
    }

    final future = _fetchOEmbedCover(id);
    _inFlight[id] = future;

    try {
      final coverUrl = await future;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        _cache[id] = coverUrl;
      }
      return coverUrl;
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<String?> _fetchOEmbedCover(String trackId) async {
    try {
      final oEmbedUrl = Uri.parse(
        'https://open.spotify.com/oembed?url=https://open.spotify.com/track/$trackId',
      );

      final response = await http.get(oEmbedUrl).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final thumb = data['thumbnail_url'] as String?;
          if (thumb != null && thumb.isNotEmpty) {
            return thumb;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpotifyCoverService] Erro ao buscar oEmbed para $trackId: $e');
      }
    }
    return null;
  }
}

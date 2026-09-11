import 'spotify_session.dart';

import 'dart:convert';

import 'package:dart_des/dart_des.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/track_model.dart';

/// Resultado da busca de músicas.
class SearchResult {
  final List<TrackModel> tracks;
  final bool isFromCache;

  const SearchResult({required this.tracks, this.isFromCache = false});
}

/// Serviço de catálogo e busca de músicas com áudio completo.
///
/// Oferece faixas com áudio completo e alta fidelidade de sincronização
/// para o feed da Home e suporte a busca com descriptografia de streams 320kbps.
class SpotifyService {
  static const _iTunesSearchBase = 'https://itunes.apple.com/search';
  static const _saavnSearchBase = 'https://www.jiosaavn.com/api.php';
  static const _timeout = Duration(seconds: 10);

  // Cache de buscas em memória
  final Map<String, List<TrackModel>> _searchCache = {};

  /// Catálogo curado de músicas populares para o Home Feed com áudio completo e sincronizado.
  static List<TrackModel> get curatedTracks => _curatedTracks;

  static const List<TrackModel> _curatedTracks = [
    // Inglês
    TrackModel(
      id: 'spotify:track:7qiZfU4dY1lWllzX7mPBI3',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: '÷ (Deluxe)',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/28/d6/fb/28d6fb87-d5cb-e2b2-df3e-45d6a804c0b2/00602547964601.rgb.jpg/600x600bb.jpg',
      previewAudioUrl: 'assets/audio/shape_of_you.mp3',
      spotifyUrl: 'https://open.spotify.com/track/7qiZfU4dY1lWllzX7mPBI3',
      duration: 263,
      language: 'en',
    ),
    TrackModel(
      id: 'saavn:track:blinding_lights',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/8e/3c/69/8e3c6981-d007-aa31-16cb-40292b349b6b/19UMGIM08436.rgb.jpg/600x600bb.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/809/4805bce54d5079d05c8eba3678b27a35_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
      duration: 183,
      language: 'en',
    ),
    TrackModel(
      id: 'saavn:track:someone_like_you',
      title: 'Someone Like You',
      artist: 'Adele',
      album: '21',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/3d/9d/38/3d9d3811-e2cf-3620-834c-623bb6f78810/886443310065.jpg/600x600bb.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/258/12fc9e12cfd9fd0abfdb7ba60e69cb17_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/4kflIGfjdZJW4ot2ioixTB',
      duration: 238,
      language: 'en',
    ),

    // Espanhol
    TrackModel(
      id: 'saavn:track:despacito',
      title: 'Despacito',
      artist: 'Luis Fonsi',
      album: 'VIDA',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/bf/f4/bf/bff4bf8d-b873-1959-1785-5b8f28d8b9ec/17UMGIM01077.rgb.jpg/600x600bb.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/438/6d63950ec29f84687543340038a796f8_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/6habFhsOp2NvshLv26DqMb',
      duration: 165,
      language: 'es',
    ),

    // Português
    TrackModel(
      id: 'saavn:track:garota_de_ipanema',
      title: 'Garota de Ipanema',
      artist: 'Tom Jobim & Stan Getz',
      album: 'Getz/Gilberto',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/35/3d/bf/353dbfed-71ce-bfa4-37bc-78d1efad7402/00602537756186.rgb.jpg/600x600bb.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/624/1430963e3a0cea436366bef7fe215df2_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/3NdDpSvN911NVWqzFLi99P',
      duration: 191,
      language: 'pt',
    ),

    // Francês
    TrackModel(
      id: 'saavn:track:papaoutai',
      title: 'Papaoutai',
      artist: 'Stromae',
      album: 'Racine Carrée',
      albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/62/7b/03/627b0365-2767-fbb5-e0c1-37d45fbe2f1b/00602537446544.rgb.jpg/600x600bb.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/589/32453c3d266f028b254698a95b0f01b1_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/1mo6fDqU1i82D3o0mF80v0',
      duration: 173,
      language: 'fr',
    ),
    TrackModel(
      id: 'saavn:track:derniere_danse',
      title: 'Dernière Danse',
      artist: 'Indila',
      album: 'Mini World',
      albumArtUrl: 'https://c.saavncdn.com/078/AiSh-The-Covers-Collection-Hindi-2022-20260710184759-500x500.jpg',
      previewAudioUrl: 'https://aac.saavncdn.com/078/498ca8f401cf7cf83eaa4fe79c2b2dd8_320.mp4',
      spotifyUrl: 'https://open.spotify.com/track/65uoaqX5qcjRJzySilHGUR',
      duration: 185,
      language: 'fr',
    ),
  ];

  /// Descriptografa URLs do JioSaavn usando DES-ECB com a chave pública de áudio.
  static String? _decryptSaavnUrl(String? encUrl) {
    if (encUrl == null || encUrl.isEmpty) return null;
    try {
      final key = utf8.encode('38346591');
      final des = DES(key: key, mode: DESMode.ECB);
      final encBytes = base64.decode(encUrl);
      final decrypted = des.decrypt(encBytes);
      final url = utf8.decode(decrypted).trim();
      return url.replaceAll('_96.mp4', '_320.mp4');
    } catch (_) {
      return null;
    }
  }

  /// Busca músicas com prioridade para faixas completas (JioSaavn) e fallback para iTunes.
  Future<SearchResult> searchTracks(String query) async {
    if (query.trim().isEmpty) return const SearchResult(tracks: []);
    if (SpotifySession.instance.connected) {
      try {
        final spotifyResults = await SpotifySession.instance.search(query);
        if (spotifyResults.isNotEmpty) {
          return SearchResult(tracks: spotifyResults);
        }
      } catch (_) {}
    }

    final cacheKey = query.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      return SearchResult(tracks: _searchCache[cacheKey]!, isFromCache: true);
    }

    try {
      // 1. Busca no catálogo global do iTunes (metadata e artwork perfeitos)
      final itunesTracks = await _searchItunes(query);
      // 2. Busca no catálogo de áudio completo (JioSaavn 320kbps full track)
      final saavnTracks = await _searchSaavn(query);

      final saavnMap = <String, TrackModel>{};
      for (final t in saavnTracks) {
        if (t.previewAudioUrl != null && t.previewAudioUrl!.startsWith('http')) {
          final key = _normalizeKey(t.artist, t.title);
          saavnMap[key] = t;
        }
      }

      final List<TrackModel> resultList = [];
      for (final t in itunesTracks) {
        final key = _normalizeKey(t.artist, t.title);
        TrackModel? fullMatch = saavnMap[key];

        if (fullMatch == null) {
          final titleKey = _normalizeString(t.title);
          for (final entry in saavnMap.entries) {
            if (entry.key.contains(titleKey)) {
              fullMatch = entry.value;
              break;
            }
          }
        }

        if (fullMatch != null && fullMatch.previewAudioUrl != null) {
          resultList.add(t.copyWith(
            previewAudioUrl: fullMatch.previewAudioUrl,
            duration: fullMatch.duration ?? t.duration,
          ));
        } else {
          resultList.add(t);
        }
      }

      for (final t in saavnTracks) {
        final key = _normalizeKey(t.artist, t.title);
        if (!resultList.any((it) => _normalizeKey(it.artist, it.title) == key)) {
          resultList.add(t);
        }
      }

      if (resultList.isNotEmpty) {
        _searchCache[cacheKey] = resultList;
        return SearchResult(tracks: resultList);
      }

      return const SearchResult(tracks: []);
    } catch (_) {
      return const SearchResult(tracks: []);
    }
  }

  /// Resolve uma faixa do Spotify para uma URL de áudio nativa (iTunes / JioSaavn).
  Future<String?> resolveToPlayableAudioUrl(TrackModel track) async {
    if (track.previewAudioUrl != null &&
        !track.previewAudioUrl!.startsWith('spotify:track:') &&
        track.previewAudioUrl!.startsWith('http')) {
      return track.previewAudioUrl;
    }

    try {
      final cleanTitle = _cleanSearchTerm(track.title);
      final cleanArtist = _cleanSearchTerm(track.artist);
      final query = '$cleanArtist $cleanTitle'.trim();

      // 1. Busca via iTunes (Garante URL HTTP/HTTPS direta de áudio M4A)
      final itunesTracks = await _searchItunes(query.isNotEmpty ? query : track.title);
      if (itunesTracks.isNotEmpty &&
          itunesTracks.first.previewAudioUrl != null &&
          itunesTracks.first.previewAudioUrl!.startsWith('http')) {
        return itunesTracks.first.previewAudioUrl;
      }

      // 2. Fallback via JioSaavn (Stream de áudio MP4 320kbps completo)
      final saavnTracks = await _searchSaavn(query.isNotEmpty ? query : track.title);
      if (saavnTracks.isNotEmpty &&
          saavnTracks.first.previewAudioUrl != null &&
          saavnTracks.first.previewAudioUrl!.startsWith('http')) {
        return saavnTracks.first.previewAudioUrl;
      }
    } catch (_) {}

    return null;
  }

  String _cleanSearchTerm(String str) {
    return str
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'-.*$', caseSensitive: false), '')
        .trim();
  }

  /// Tenta buscar a versão de áudio COMPLETO no catálogo para faixas que têm prévia de 30s.
  Future<TrackModel> fetchFullAudioStream(TrackModel track) async {
    if (track.id.startsWith('saavn:') ||
        track.previewAudioUrl == null ||
        track.previewAudioUrl!.startsWith('assets/')) {
      return track;
    }

    try {
      final query = '${track.artist} ${track.title}';
      final saavnTracks = await _searchSaavn(query);
      if (saavnTracks.isNotEmpty) {
        final fullAudioUrl = saavnTracks.first.previewAudioUrl;
        if (fullAudioUrl != null && fullAudioUrl.startsWith('http')) {
          return track.copyWith(
            previewAudioUrl: fullAudioUrl,
            duration: saavnTracks.first.duration ?? track.duration,
          );
        }
      }
    } catch (_) {}

    return track;
  }

  String _normalizeKey(String artist, String title) {
    return '${_normalizeString(artist)}_${_normalizeString(title)}';
  }

  String _normalizeString(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<List<TrackModel>> _searchSaavn(String query) async {
    try {
      final uri = Uri.parse(_saavnSearchBase).replace(
        queryParameters: {
          '__call': 'search.getResults',
          'q': query,
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
        },
      );

      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      final List<TrackModel> tracks = [];
      for (final r in results) {
        final item = r as Map<String, dynamic>;
        final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
        final encUrl = moreInfo['encrypted_media_url'] as String?;
        final audioUrl = _decryptSaavnUrl(encUrl);
        if (audioUrl == null) continue;

        final rawTitle = (item['title'] as String? ?? 'Unknown')
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&');
        final rawArtist =
            (moreInfo['music'] as String? ??
                    item['subtitle'] as String? ??
                    'Unknown')
                .replaceAll('&quot;', '"')
                .replaceAll('&amp;', '&');

        final artUrl = (item['image'] as String?)?.replaceAll(
          '150x150',
          '500x500',
        );

        final durStr = moreInfo['duration']?.toString();
        final duration = durStr != null ? double.tryParse(durStr) : null;

        tracks.add(
          TrackModel(
            id: 'saavn:${item['id']}',
            title: rawTitle,
            artist: rawArtist,
            album: (moreInfo['album'] as String? ?? ''),
            albumArtUrl: artUrl,
            previewAudioUrl: audioUrl,
            spotifyUrl: item['perma_url'] as String?,
            duration: duration,
            language: _guessLanguageByName(item['language'] as String? ?? ''),
          ),
        );
      }

      return tracks;
    } catch (_) {
      return [];
    }
  }

  Future<List<TrackModel>> _searchItunes(String query) async {
    try {
      final uri = Uri.parse(_iTunesSearchBase).replace(
        queryParameters: {
          'term': query,
          'entity': 'song',
          'limit': '20',
          'media': 'music',
        },
      );

      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      return results
          .where((r) => r['previewUrl'] != null)
          .map(_mapItunesResult)
          .toList();
    } catch (_) {
      return [];
    }
  }

  TrackModel _mapItunesResult(dynamic r) {
    final result = r as Map<String, dynamic>;
    final artUrl = (result['artworkUrl100'] as String?)?.replaceAll(
      '100x100bb',
      '600x600bb',
    );

    return TrackModel(
      id: 'itunes:${result['trackId']}',
      title: result['trackName'] as String? ?? 'Unknown',
      artist: result['artistName'] as String? ?? 'Unknown',
      album: result['collectionName'] as String? ?? '',
      albumArtUrl: artUrl,
      previewAudioUrl: result['previewUrl'] as String?,
      spotifyUrl: result['trackViewUrl'] as String?,
      duration: (result['trackTimeMillis'] as num?)?.toDouble() != null
          ? (result['trackTimeMillis'] as num).toDouble() / 1000
          : null,
      language: _guessLanguage(result),
    );
  }

  String _guessLanguageByName(String lang) {
    final l = lang.toLowerCase();
    if (l.contains('portuguese') || l == 'pt') return 'pt';
    if (l.contains('spanish') || l == 'es') return 'es';
    if (l.contains('french') || l == 'fr') return 'fr';
    return 'en';
  }

  String _guessLanguage(Map<String, dynamic> result) {
    final country = (result['country'] as String?)?.toLowerCase() ?? 'usa';
    if (country == 'bra') return 'pt';
    if (country == 'esp' || country == 'mex') return 'es';
    if (country == 'fra') return 'fr';
    return 'en';
  }

  /// Abre uma URL (Spotify ou Apple Music) no navegador/app externo.
  Future<void> openExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

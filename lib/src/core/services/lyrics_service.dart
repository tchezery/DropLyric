import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lyric_line_model.dart';
import '../models/track_model.dart';

/// Resultado de busca de letras da API LRCLIB.
class LyricsResult {
  final List<LyricLine> lines;
  final bool
  isSynced; // true se veio com timestamps LRC, false se é texto simples
  final String? plainText;

  const LyricsResult({
    required this.lines,
    required this.isSynced,
    this.plainText,
  });
}

/// A LRCLIB record identifies a lyrics version, never a Spotify recording.
class LyricsSearchEntry {
  final TrackModel track;
  final LyricsResult? lyrics;
  final bool instrumental;
  const LyricsSearchEntry({
    required this.track,
    this.lyrics,
    required this.instrumental,
  });
}

/// Serviço de busca de letras via LRCLIB API com cache em memória.
class LyricsService {
  LyricsService({this.client});
  final http.Client? client;

  Future<List<LyricsSearchEntry>> search(String query) async {
    query = query.trim();
    if (query.isEmpty) return [];
    final response = await (client?.get ?? http.get)(
      Uri.parse('$_baseUrl/search').replace(queryParameters: {'q': query}),
      headers: {'Lrclib-Client': 'DropLyric/1.0.0'},
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('LRCLIB: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw const FormatException('Invalid LRCLIB response');
    return data
        .whereType<Map<String, dynamic>>()
        .where(
          (item) =>
              item['id'] is num &&
              item['trackName'] is String &&
              item['artistName'] is String,
        )
        .map(
          (item) => LyricsSearchEntry(
            track: TrackModel(
              id: 'lrclib:${item['id']}',
              title: item['trackName'] as String,
              artist: item['artistName'] as String,
              album: item['albumName'] as String? ?? '',
              duration: (item['duration'] as num?)?.toDouble(),
            ),
            lyrics: _parseResponse(item),
            instrumental: item['instrumental'] == true,
          ),
        )
        .toList();
  }

  // Cache simples em memória (chave: "artist|title")
  final Map<String, LyricsResult> _cache = {};

  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 10);

  /// Busca a letra de uma música.
  /// Tenta obter letra sincronizada (LRC) e fallback para texto simples.
  Future<LyricsResult?> getLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    double? duration,
  }) async {
    final cleanTrack = trackName.trim();
    final cleanArtist = artistName.trim();
    if (cleanTrack.isEmpty) return null;

    final cacheKey =
        '${cleanArtist.toLowerCase()}|${cleanTrack.toLowerCase()}|${albumName?.toLowerCase()}|$duration';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // 1. Tenta o endpoint direto (/get) com todos os metadados
    final validAlbum = (albumName != null &&
            albumName.isNotEmpty &&
            albumName != 'YouTube Music')
        ? albumName
        : null;

    var result = await _fetchFromGet(
      trackName: cleanTrack,
      artistName: cleanArtist,
      albumName: validAlbum,
      duration: duration,
    );

    // 2. Tenta /get sem álbum e sem duração (caso duração tenha divergência de segundos)
    if (result == null && (validAlbum != null || duration != null)) {
      result = await _fetchFromGet(
        trackName: cleanTrack,
        artistName: cleanArtist,
      );
    }

    // 3. Fallback: busca via /search com "Artista Faixa"
    if (result == null && cleanArtist.isNotEmpty) {
      result = await _fetchFromSearch(
        query: '$cleanArtist $cleanTrack',
      );
    }

    // 4. Se o artista tiver múltiplos nomes (vírgula, feat, &), tenta apenas o primeiro artista
    if (result == null && cleanArtist.isNotEmpty) {
      final primaryArtist = cleanArtist
          .split(RegExp(r'[,&]|\s+(feat\.?|ft\.?)\s+', caseSensitive: false))[0]
          .trim();
      if (primaryArtist.isNotEmpty && primaryArtist != cleanArtist) {
        result = await _fetchFromSearch(
          query: '$primaryArtist $cleanTrack',
        );
      }
    }

    // 5. Fallback final: busca via /search apenas pelo nome da faixa
    result ??= await _fetchFromSearch(
      query: cleanTrack,
    );

    if (result != null) {
      _cache[cacheKey] = result;
    }

    return result;
  }

  Future<LyricsResult?> _fetchFromGet({
    required String trackName,
    required String artistName,
    String? albumName,
    double? duration,
  }) async {
    try {
      final queryParams = {
        'track_name': trackName,
        'artist_name': artistName,
        'album_name': albumName,
        if (duration != null) 'duration': duration.toString(),
      };
      queryParams.removeWhere((_, v) => v == null);

      final uri = Uri.parse('$_baseUrl/get')
          .replace(queryParameters: queryParams);

      final response = await (client?.get(uri) ?? http.get(uri))
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(data);
    } catch (_) {
      return null;
    }
  }

  Future<LyricsResult?> _fetchFromSearch({required String query}) async {
    try {
      final uri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': query});

      final response = await (client?.get(uri) ?? http.get(uri))
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;

      LyricsResult? firstPlain;

      for (final item in data.whereType<Map<String, dynamic>>()) {
        final parsed = _parseResponse(item);
        if (parsed != null) {
          // Preferência por letras sincronizadas
          if (parsed.isSynced) return parsed;
          firstPlain ??= parsed;
        }
      }

      return firstPlain;
    } catch (_) {
      return null;
    }
  }

  LyricsResult? _parseResponse(Map<String, dynamic> data) {
    final syncedLyrics = data['syncedLyrics'] as String?;
    final plainLyrics = data['plainLyrics'] as String?;

    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      final lines = LyricParser.parseLrc(syncedLyrics);
      if (lines.isNotEmpty) {
        return LyricsResult(
          lines: lines,
          isSynced: true,
          plainText: plainLyrics,
        );
      }
    }

    if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      final lines = LyricParser.parsePlain(plainLyrics);
      if (lines.isNotEmpty) {
        return LyricsResult(
          lines: lines,
          isSynced: false,
          plainText: plainLyrics,
        );
      }
    }

    return null;
  }
}

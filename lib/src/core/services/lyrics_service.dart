import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lyric_line_model.dart';

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

/// Serviço de busca de letras via LRCLIB API com cache em memória.
class LyricsService {
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
    final cacheKey =
        '${artistName.toLowerCase()}|${trackName.toLowerCase()}|${albumName?.toLowerCase()}|$duration';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // Tenta o endpoint direto (/get) para letras sincronizadas com mais precisão
    final result = await _fetchFromGet(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
    );

    if (result != null) {
      _cache[cacheKey] = result;
      return result;
    }

    // Fallback: busca via /search (retorna lista, pega o primeiro)
    final searchResult = await _fetchFromSearch(
      query: '$artistName $trackName',
    );

    if (searchResult != null) {
      _cache[cacheKey] = searchResult;
    }

    return searchResult;
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

      final response = await http.get(uri).timeout(_timeout);

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

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;

      // Pega o primeiro resultado
      return _parseResponse(data.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  LyricsResult? _parseResponse(Map<String, dynamic> data) {
    final syncedLyrics = data['syncedLyrics'] as String?;
    final plainLyrics = data['plainLyrics'] as String?;

    if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
      final lines = LyricParser.parseLrc(syncedLyrics);
      if (lines.isNotEmpty) {
        return LyricsResult(
          lines: lines,
          isSynced: true,
          plainText: plainLyrics,
        );
      }
    }

    if (plainLyrics != null && plainLyrics.isNotEmpty) {
      return LyricsResult(
        lines: LyricParser.parsePlain(plainLyrics),
        isSynced: false,
        plainText: plainLyrics,
      );
    }

    return null;
  }
}

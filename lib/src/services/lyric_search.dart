import 'dart:convert';
import 'package:http/http.dart' as http;

class Lyrics {
  final int id;
  final String name;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String plainLyrics;
  final String syncedLyrics;

  Lyrics({
    required this.id,
    required this.name,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    required this.plainLyrics,
    required this.syncedLyrics,
  });

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      // A API envia em camelCase conforme a documentação
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String? ?? '',
      syncedLyrics: json['syncedLyrics'] as String? ?? '',
    );
  }
}

class LyricService {
  static const String _baseUrl = 'https://lrclib.net/api/search';

  Future<List<Lyrics>> searchByTerm(String term) async {
    if (term.trim().isEmpty) return [];

    final url = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(term)}');

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'DropLyric/1.0.0 (tchezeryribeiro@gmail.com)',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Lyrics.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        print('Erro na requisição: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar dados: $e');
      return [];
    }
  }
}

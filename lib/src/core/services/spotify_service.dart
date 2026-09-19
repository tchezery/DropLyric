import '../models/track_model.dart';
import 'spotify_session.dart';

class SearchResult {
  final List<TrackModel> tracks;
  const SearchResult({required this.tracks});
}

/// Catálogo exclusivamente Spotify.
class SpotifyService {
  static List<TrackModel> get curatedTracks => _curatedTracks;
  static const List<TrackModel> _curatedTracks = [
    // Inglês
    TrackModel(
      id: 'spotify:track:7qiZfU4dY1lWllzX7mPBI3',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: '÷ (Deluxe)',
      previewAudioUrl: 'spotify:track:7qiZfU4dY1lWllzX7mPBI3',
      spotifyUrl: 'https://open.spotify.com/track/7qiZfU4dY1lWllzX7mPBI3',
      duration: 263,
      language: 'en',
    ),
    TrackModel(
      id: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      previewAudioUrl: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
      spotifyUrl: 'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
      duration: 183,
      language: 'en',
    ),
    TrackModel(
      id: 'spotify:track:4kflIGfjdZJW4ot2ioixTB',
      title: 'Someone Like You',
      artist: 'Adele',
      album: '21',
      previewAudioUrl: 'spotify:track:4kflIGfjdZJW4ot2ioixTB',
      spotifyUrl: 'https://open.spotify.com/track/4kflIGfjdZJW4ot2ioixTB',
      duration: 238,
      language: 'en',
    ),

    // Espanhol
    TrackModel(
      id: 'spotify:track:6habFhsOp2NvshLv26DqMb',
      title: 'Despacito',
      artist: 'Luis Fonsi',
      album: 'VIDA',
      previewAudioUrl: 'spotify:track:6habFhsOp2NvshLv26DqMb',
      spotifyUrl: 'https://open.spotify.com/track/6habFhsOp2NvshLv26DqMb',
      duration: 165,
      language: 'es',
    ),

    // Português
    TrackModel(
      id: 'spotify:track:3NdDpSvN911NVWqzFLi99P',
      title: 'Garota de Ipanema',
      artist: 'Tom Jobim & Stan Getz',
      album: 'Getz/Gilberto',
      previewAudioUrl: 'spotify:track:3NdDpSvN911NVWqzFLi99P',
      spotifyUrl: 'https://open.spotify.com/track/3NdDpSvN911NVWqzFLi99P',
      duration: 191,
      language: 'pt',
    ),

    // Francês
    TrackModel(
      id: 'spotify:track:1mo6fDqU1i82D3o0mF80v0',
      title: 'Papaoutai',
      artist: 'Stromae',
      album: 'Racine Carrée',
      previewAudioUrl: 'spotify:track:1mo6fDqU1i82D3o0mF80v0',
      spotifyUrl: 'https://open.spotify.com/track/1mo6fDqU1i82D3o0mF80v0',
      duration: 173,
      language: 'fr',
    ),
    TrackModel(
      id: 'spotify:track:65uoaqX5qcjRJzySilHGUR',
      title: 'Dernière Danse',
      artist: 'Indila',
      album: 'Mini World',
      previewAudioUrl: 'spotify:track:65uoaqX5qcjRJzySilHGUR',
      spotifyUrl: 'https://open.spotify.com/track/65uoaqX5qcjRJzySilHGUR',
      duration: 185,
      language: 'fr',
    ),
  ];

  static String? playbackUri(String source, {TrackModel? track}) {
    final valid = RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$');
    if (track != null && valid.hasMatch(track.id)) return track.id;
    if (valid.hasMatch(source)) return source;
    final link = Uri.tryParse(track?.spotifyUrl ?? source.trim());
    if (link?.scheme == 'https' &&
        link?.host == 'open.spotify.com' &&
        (link!.pathSegments.length == 2 ||
            (link.pathSegments.length == 3 &&
                link.pathSegments.first.startsWith('intl-'))) &&
        link.pathSegments[link.pathSegments.length - 2] == 'track') {
      final uri = 'spotify:track:${link.pathSegments.last}';
      if (valid.hasMatch(uri)) return uri;
    }
    return null;
  }

  Future<SearchResult> searchTracks(String query) async {
    if (query.trim().isEmpty) return const SearchResult(tracks: []);
    if (!SpotifySession.instance.connected) {
      throw StateError('Connect your Spotify account to search for music.');
    }
    return SearchResult(tracks: await SpotifySession.instance.search(query));
  }
}

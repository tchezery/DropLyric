import 'dart:convert';
import 'spotify_mobile_auth.dart';

const spotifyWebSupported = true;

Future<String> spotifyCall(String action, [String argument = '']) async {
  final auth = SpotifyMobileAuth.instance;
  if (action == 'login') {
    await auth.login();
    return '{}';
  } else if (action == 'logout') {
    await auth.logout();
    return '{}';
  } else if (action == 'search') {
    final tracks = await auth.searchSpotify(argument);
    return jsonEncode({
      'tracks': {
        'items':
            tracks
                .map(
                  (t) => {
                    'uri': t.id,
                    'name': t.title,
                    'artists': [
                      {'name': t.artist},
                    ],
                    'album': {
                      'name': t.album,
                      'images':
                          t.albumArtUrl != null
                              ? [
                                {'url': t.albumArtUrl},
                              ]
                              : [],
                    },
                    'preview_url': t.previewAudioUrl,
                    'external_urls': {'spotify': t.spotifyUrl},
                    'duration_ms':
                        t.duration != null ? (t.duration! * 1000).toInt() : 0,
                  },
                )
                .toList(),
      },
    });
  }
  return '{}';
}

String spotifyState() {
  final auth = SpotifyMobileAuth.instance;
  return jsonEncode({
    'authenticated': auth.isAuthenticated,
    'ready': false,
    'error': auth.error,
    'uri': '',
    'paused': true,
    'position': 0,
    'duration': 0,
    'displayName': auth.userDisplayName,
  });
}

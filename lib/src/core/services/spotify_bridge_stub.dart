import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'spotify_mobile_auth.dart';

const spotifyWebSupported = true;
const _remote = MethodChannel('droplyric/spotify');
Map<String, dynamic> _playback = {};
final _clock = Stopwatch()..start();
int _sampledAt = 0;
bool _listening = false;
void _listen() {
  if (_listening || defaultTargetPlatform != TargetPlatform.android) return;
  _listening = true;
  const EventChannel(
    'droplyric/spotify/events',
  ).receiveBroadcastStream().listen(
    (event) {
      _playback = Map<String, dynamic>.from(event as Map);
      _sampledAt = _clock.elapsedMilliseconds;
    },
    onError: (Object error) {
      _playback = {'ready': false, 'paused': true, 'error': error.toString()};
    },
  );
}

Future<String> spotifyCall(String action, [String argument = '']) async {
  final auth = SpotifyMobileAuth.instance;
  _listen();
  if (['play', 'pause', 'seek'].contains(action)) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Player Spotify indisponível nesta plataforma.');
    }
    try {
      if (action == 'play' &&
          !RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$').hasMatch(argument)) {
        throw ArgumentError('Faixa Spotify inválida.');
      }
      _playback['error'] = '';
      await _remote.invokeMethod<void>(action, argument);
    } on PlatformException catch (e) {
      _playback['error'] = e.message ?? 'Falha no player Spotify.';
      rethrow;
    }
    return '{}';
  } else if (action == 'track') {
    return jsonEncode(await auth.getTrack(argument));
  } else if (action == 'login') {
    await auth.login();
    return '{}';
  } else if (action == 'logout') {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _remote.invokeMethod<void>('disconnect');
    }
    _playback = {};
    await auth.logout();
    return '{}';
  } else if (action == 'search') {
    final tracks = await auth.searchSpotify(argument);
    return jsonEncode({
      'tracks': {
        'items': tracks
            .map(
              (t) => {
                'uri': t.id,
                'name': t.title,
                'artists': [
                  {'name': t.artist},
                ],
                'album': {
                  'name': t.album,
                  'images': t.albumArtUrl != null
                      ? [
                          {'url': t.albumArtUrl},
                        ]
                      : [],
                },
                'preview_url': t.previewAudioUrl,
                'external_urls': {'spotify': t.spotifyUrl},
                'duration_ms': t.duration != null
                    ? (t.duration! * 1000).toInt()
                    : 0,
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
    ..._playback,
    'error': (_playback['error'] as String? ?? '').isNotEmpty
        ? _playback['error']
        : auth.error,
    'position':
        ((_playback['position'] as num? ?? 0) +
                (_playback['paused'] == false && _playback['ready'] == true
                    ? _clock.elapsedMilliseconds - _sampledAt
                    : 0))
            .clamp(0, _playback['duration'] as num? ?? 0),
    'displayName': auth.userDisplayName,
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get spotifyWebSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
const _remote = MethodChannel('droplyric/spotify');
Map<String, dynamic> _playback = {};
final _clock = Stopwatch()..start();
int _sampledAt = 0;
bool _listening = false;
bool _connecting = false;
bool _initializing = false;
String _error = '';
void _listen() {
  if (_listening || !spotifyWebSupported) return;
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
  if (!spotifyWebSupported) {
    throw StateError(
      'Use o DropLyric no Android, iPhone ou Mac para conectar ao Spotify.',
    );
  }
  _listen();
  if (action == 'play' &&
      !RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$').hasMatch(argument)) {
    throw ArgumentError('Cole o link completo de uma faixa do Spotify.');
  }
  final method = switch (action) {
    'login' || 'loginApp' || 'loginWeb' => 'connect',
    'logout' => 'disconnect',
    _ => action,
  };
  if (method == 'search' || method == 'track') {
    throw UnsupportedError(
      'A busca de catálogo não está disponível neste modo.',
    );
  }
  _initializing = method == 'initialize';
  _connecting = method == 'connect';
  _error = '';
  try {
    final result = await _remote.invokeMethod<Object?>(method, argument);
    if (method == 'disconnect') _playback = {};
    return jsonEncode(result ?? {});
  } on PlatformException catch (e) {
    _error = e.message ?? 'Não foi possível conectar ao Spotify.';
    rethrow;
  } finally {
    _initializing = false;
    _connecting = false;
  }
}

String spotifyState() => jsonEncode({
  ..._playback,
  'authenticated':
      _playback['appRemoteAuthorized'] == true || _playback['ready'] == true,
  'initializing': _initializing,
  'connecting': _connecting || _playback['connecting'] == true,
  'error': _error.isNotEmpty ? _error : (_playback['error'] ?? ''),
  'position':
      (((_playback['position'] as num?) ?? 0) +
              (_playback['paused'] == false && _playback['ready'] == true
                  ? _clock.elapsedMilliseconds - _sampledAt
                  : 0))
          .clamp(0, (_playback['duration'] as num?) ?? 0),
});

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import 'spotify_bridge.dart';
import 'saved_tracks.dart';

class SpotifySession extends ChangeNotifier {
  static final instance = SpotifySession._();
  SpotifySession._() {
    if (supported) {
      spotifyCall('initialize')
          .then((_) => _update())
          .catchError((Object _) {});
      Timer.periodic(const Duration(milliseconds: 100), (_) => _update());
    }
  }
  final ChangeNotifier playbackChanges = ChangeNotifier();
  bool get remoteOnly => !kIsWeb;
  bool get supported => spotifyWebSupported;
  TrackModel? get currentTrack {
    if (!RegExp(r'^spotify:track:[a-zA-Z0-9]{22}$').hasMatch(uri) ||
        (state['title'] as String? ?? '').isEmpty) {
      return null;
    }
    return TrackModel(
      id: uri,
      title: state['title'] as String,
      artist: state['artist'] as String? ?? '',
      album: state['album'] as String? ?? '',
      previewAudioUrl: uri,
      spotifyUrl: 'https://open.spotify.com/track/${uri.split(':').last}',
      duration: duration.inMilliseconds / 1000,
    );
  }

  Future<List<Map<String, dynamic>>> content([String parent = '']) async {
    final data = jsonDecode(await spotifyCall('content', parent)) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Map<String, dynamic> state = {};
  bool get connected => state['authenticated'] == true;
  bool get appRemoteAuthorized => state['appRemoteAuthorized'] == true;
  bool get fullyConnected =>
      connected && appRemoteAuthorized && state['ready'] == true;
  bool get initializing => state.isEmpty || state['initializing'] == true;
  bool get connecting => state['connecting'] == true;
  String get error => state['error'] as String? ?? '';
  String get uri => state['uri'] as String? ?? '';
  bool get paused => state['paused'] != false;
  Duration get position =>
      Duration(milliseconds: (state['position'] as num? ?? 0).round());
  Duration get duration =>
      Duration(milliseconds: (state['duration'] as num? ?? 0).round());
  void _update() {
    final next = jsonDecode(spotifyState()) as Map<String, dynamic>;
    final accountChanged =
        state['initializing'] != next['initializing'] ||
        state['connecting'] != next['connecting'] ||
        state['authenticated'] != next['authenticated'] ||
        state['appRemoteAuthorized'] != next['appRemoteAuthorized'] ||
        state['ready'] != next['ready'] ||
        state['error'] != next['error'];
    final playbackChanged =
        state['uri'] != next['uri'] ||
        state['title'] != next['title'] ||
        state['artist'] != next['artist'] ||
        state['album'] != next['album'] ||
        state['paused'] != next['paused'] ||
        state['position'] != next['position'] ||
        state['duration'] != next['duration'];
    final trackChanged = state['uri'] != next['uri'];
    final metadataChanged =
        state['uri'] != next['uri'] ||
        state['title'] != next['title'] ||
        state['artist'] != next['artist'];
    state = next;
    if (remoteOnly &&
        state['ready'] == true &&
        metadataChanged &&
        currentTrack != null) {
      unawaited(
        SavedTracks.instance.remember(currentTrack!).catchError((Object error) {
          debugPrint('Could not save listening history: $error');
        }),
      );
    }
    if (accountChanged || trackChanged || playbackChanged) notifyListeners();
    if (playbackChanged || accountChanged) playbackChanges.notifyListeners();
  }

  Future<void> command(String action, [String argument = '']) async {
    try {
      await spotifyCall(action, argument);
    } finally {
      if (supported) _update();
    }
  }

  Future<List<TrackModel>> search(String query) async {
    final data =
        jsonDecode(await spotifyCall('search', query)) as Map<String, dynamic>;
    return ((data['tracks']?['items'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .where((t) => t['is_playable'] != false)
        .map(fromJson)
        .toList();
  }

  Future<TrackModel> resolve(TrackModel track) async {
    if (remoteOnly) {
      final current = currentTrack;
      return current?.id == track.id
          ? current!.copyWith(language: track.language)
          : track;
    }
    // A busca já devolve os metadados completos do Spotify.
    if (track.id.startsWith('spotify:track:') &&
        track.previewAudioUrl == track.id) {
      return track;
    }
    final url = Uri.tryParse(track.spotifyUrl ?? '');
    final id = track.id.startsWith('spotify:track:')
        ? track.id.split(':').last
        : url?.host == 'open.spotify.com' &&
              url!.pathSegments.length == 2 &&
              url.pathSegments.first == 'track'
        ? url.pathSegments.last
        : null;
    if (id == null) return track;
    try {
      final jsonStr = await spotifyCall('track', id);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data.containsKey('name') && data.containsKey('uri')) {
        return fromJson(data).copyWith(language: track.language);
      }
    } catch (_) {}
    return track;
  }

  static TrackModel fromJson(Map<String, dynamic> data) {
    final album = data['album'] as Map<String, dynamic>? ?? {};
    final images = album['images'] as List? ?? [];
    final uri = data['uri'] as String;
    return TrackModel(
      id: uri,
      title: data['name'] as String,
      artist: (data['artists'] as List).map((a) => a['name']).join(', '),
      album: album['name'] as String? ?? '',
      albumArtUrl: images.isEmpty ? null : images.first['url'] as String?,
      previewAudioUrl: uri,
      spotifyUrl: data['external_urls']?['spotify'] as String?,
      duration: (data['duration_ms'] as num).toDouble() / 1000,
      language: '',
    );
  }
}

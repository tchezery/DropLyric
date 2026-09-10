import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import 'spotify_bridge.dart';

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
  bool get supported => spotifyWebSupported;
  Map<String, dynamic> state = {};
  bool get connected => state['authenticated'] == true;
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
        state['authenticated'] != next['authenticated'] ||
        state['ready'] != next['ready'] ||
        state['error'] != next['error'];
    final playbackChanged =
        state['uri'] != next['uri'] ||
        state['paused'] != next['paused'] ||
        state['position'] != next['position'] ||
        state['duration'] != next['duration'];
    state = next;
    if (accountChanged) notifyListeners();
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
    if (id == null) {
      throw StateError('Busque esta música novamente após conectar o Spotify.');
    }
    final data =
        jsonDecode(await spotifyCall('track', id)) as Map<String, dynamic>;
    return fromJson(data).copyWith(language: track.language);
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
    );
  }
}

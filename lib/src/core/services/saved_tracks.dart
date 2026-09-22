import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';
import 'sync_service.dart';

/// History and favorites belong to this installation, not the Spotify library.
class SavedTracks extends ChangeNotifier {
  static final instance = SavedTracks();
  SavedTracks() {
    ready = _restore();
  }
  late final Future<void> ready;
  final List<TrackModel> _tracks = [];
  final Set<String> _favorites = {};
  Future<void> _writes = Future.value();
  List<TrackModel> get tracks => List.unmodifiable(_tracks);
  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites.addAll(prefs.getStringList('remote_favorites') ?? []);
    for (final raw in prefs.getStringList('remote_history') ?? []) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _tracks.add(
          TrackModel(
            id: data['id'] as String,
            title: data['title'] as String,
            artist: data['artist'] as String,
            album: data['album'] as String? ?? '',
            previewAudioUrl:
                data['previewAudioUrl'] as String? ??
                ((data['id'] as String).startsWith('spotify:')
                    ? data['id'] as String
                    : null),
            albumArtUrl: data['albumArtUrl'] as String?,
            spotifyUrl: data['spotifyUrl'] as String?,
            duration: (data['duration'] as num?)?.toDouble(),
            language: data['language'] as String? ?? '',
          ),
        );
      } catch (_) {
        /* Ignore a damaged individual record. */
      }
    }
    notifyListeners();
  }

  Future<void> remember(TrackModel track) async {
    await ready;
    if (track.title.isEmpty || track.artist.isEmpty) return;
    _tracks.removeWhere((t) => t.id == track.id);
    _tracks.insert(0, track);
    final recent = _tracks.take(100).map((t) => t.id).toSet();
    _tracks.removeWhere(
      (t) => !recent.contains(t.id) && !_favorites.contains(t.id),
    );
    await _save();
    SyncService.instance.pushTrack(track).ignore();
  }

  Future<void> toggleFavorite(TrackModel track) async {
    await ready;
    final isNowFavorite = !_favorites.remove(track.id);
    if (isNowFavorite) _favorites.add(track.id);
    if (!_tracks.any((t) => t.id == track.id)) _tracks.insert(0, track);
    await _save();
    SyncService.instance
        .pushFavorite(track.id, isFavorite: isNowFavorite)
        .ignore();
  }

  /// Atualiza o estado de favorito vindo de sincronização em tempo real.
  Future<void> setFavoriteRemote(String trackId, bool isFavorite) async {
    await ready;
    final changed =
        isFavorite ? _favorites.add(trackId) : _favorites.remove(trackId);
    if (changed) {
      await _save();
    }
  }

  /// Mescla dados vindos da nuvem de uma só vez sem disparar loops de notificação.
  Future<void> mergeFromCloud(
    List<TrackModel> newTracks,
    Set<String> cloudFavorites,
  ) async {
    await ready;
    var changed = false;
    for (final favId in cloudFavorites) {
      if (_favorites.add(favId)) {
        changed = true;
      }
    }
    for (final track in newTracks) {
      if (!_tracks.any((t) => t.id == track.id)) {
        _tracks.add(track);
        changed = true;
      }
    }
    if (changed) {
      await _save();
    }
  }

  Future<void> _save() {
    notifyListeners();
    final tracks = _tracks
        .map(
          (t) => jsonEncode({
            'id': t.id,
            'title': t.title,
            'artist': t.artist,
            'album': t.album,
            'albumArtUrl': t.albumArtUrl,
            'spotifyUrl': t.spotifyUrl,
            'previewAudioUrl': t.previewAudioUrl,
            'duration': t.duration,
            'language': t.language,
          }),
        )
        .toList();
    final favorites = _favorites.toList();
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('remote_history', tracks);
      await prefs.setStringList('remote_favorites', favorites);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}

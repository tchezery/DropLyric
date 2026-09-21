import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/known_word_model.dart';
import '../models/track_model.dart';
import 'auth_service.dart';

/// Gerencia a sincronização bidirecional entre SQLite local e Supabase.
///
/// Estratégia de merge (sem perda de dados):
///   - Push: upsert dados locais na nuvem
///   - Pull: insere dados da nuvem que não existem localmente (via callback)
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => AuthService.instance.currentUser?.id;

  bool get _canSync =>
      AuthService.instance.isSignedIn && _uid != null;

  // ───────────────────────────────────────────────────────────────
  // Palavras conhecidas
  // ───────────────────────────────────────────────────────────────

  /// Envia uma palavra para a nuvem (upsert por normalized_word + language).
  /// Chamado silenciosamente após cada escrita local.
  Future<void> pushWord(KnownWordModel word) async {
    if (!_canSync) return;
    try {
      await _client.from('known_words').upsert({
        'user_id': _uid,
        'word': word.word,
        'normalized_word': word.normalizedWord,
        'language': word.language,
        'track_name': word.trackName,
        'artist_name': word.artistName,
        'created_at': word.createdAt.toIso8601String(),
      }, onConflict: 'user_id,normalized_word,language');
    } catch (e) {
      debugPrint('[SyncService] pushWord error: $e');
    }
  }

  /// Remove uma palavra da nuvem.
  Future<void> deleteWord(String normalizedWord, String language) async {
    if (!_canSync) return;
    try {
      await _client
          .from('known_words')
          .delete()
          .eq('user_id', _uid!)
          .eq('normalized_word', normalizedWord)
          .eq('language', language);
    } catch (e) {
      debugPrint('[SyncService] deleteWord error: $e');
    }
  }

  /// Puxa palavras da nuvem e retorna as que ainda não existem localmente.
  Future<List<KnownWordModel>> pullNewWords(
    Set<String> existingKeys, // "normalizedWord|language"
  ) async {
    if (!_canSync) return [];
    try {
      final rows = await _client
          .from('known_words')
          .select()
          .eq('user_id', _uid!);
      final result = <KnownWordModel>[];
      for (final row in rows) {
        final key = '${row['normalized_word']}|${row['language']}';
        if (!existingKeys.contains(key)) {
          result.add(KnownWordModel(
            word: row['word'] as String,
            normalizedWord: row['normalized_word'] as String,
            language: row['language'] as String,
            trackName: row['track_name'] as String?,
            artistName: row['artist_name'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[SyncService] pullNewWords error: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Histórico de músicas
  // ───────────────────────────────────────────────────────────────

  /// Envia uma música para o histórico na nuvem.
  Future<void> pushTrack(TrackModel track) async {
    if (!_canSync) return;
    try {
      await _client.from('history_tracks').upsert({
        'user_id': _uid,
        'track_id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'album_art': track.albumArtUrl,
        'preview_url': track.previewAudioUrl,
        'spotify_url': track.spotifyUrl,
        'language': track.language,
        'played_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,track_id');
    } catch (e) {
      debugPrint('[SyncService] pushTrack error: $e');
    }
  }

  /// Puxa histórico da nuvem e retorna as músicas novas.
  Future<List<TrackModel>> pullNewTracks(Set<String> existingIds) async {
    if (!_canSync) return [];
    try {
      final rows = await _client
          .from('history_tracks')
          .select()
          .eq('user_id', _uid!)
          .order('played_at', ascending: false)
          .limit(200);
      final result = <TrackModel>[];
      for (final row in rows) {
        final id = row['track_id'] as String;
        if (!existingIds.contains(id)) {
          result.add(TrackModel(
            id: id,
            title: row['title'] as String,
            artist: row['artist'] as String,
            album: row['album'] as String? ?? '',
            albumArtUrl: row['album_art'] as String?,
            previewAudioUrl: row['preview_url'] as String?,
            spotifyUrl: row['spotify_url'] as String?,
            language: row['language'] as String? ?? '',
          ));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[SyncService] pullNewTracks error: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Favoritos
  // ───────────────────────────────────────────────────────────────

  /// Adiciona ou remove um favorito na nuvem.
  Future<void> pushFavorite(String trackId, {required bool isFavorite}) async {
    if (!_canSync) return;
    try {
      if (isFavorite) {
        await _client.from('favorites').upsert({
          'user_id': _uid,
          'track_id': trackId,
        }, onConflict: 'user_id,track_id');
      } else {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', _uid!)
            .eq('track_id', trackId);
      }
    } catch (e) {
      debugPrint('[SyncService] pushFavorite error: $e');
    }
  }

  /// Puxa favoritos da nuvem.
  Future<Set<String>> pullFavorites() async {
    if (!_canSync) return {};
    try {
      final rows = await _client
          .from('favorites')
          .select('track_id')
          .eq('user_id', _uid!);
      return rows.map((r) => r['track_id'] as String).toSet();
    } catch (e) {
      debugPrint('[SyncService] pullFavorites error: $e');
      return {};
    }
  }
}

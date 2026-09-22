import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../models/known_word_model.dart';
import '../models/track_model.dart';
import '../repositories/known_words_repository.dart';
import 'saved_tracks.dart';
import 'supabase_config.dart';

/// Gerencia a sincronização bidirecional entre SQLite local e Supabase.
///
/// SQLite é sempre a fonte local de verdade (funciona offline 100%).
/// Quando conectado, o SyncService envia alterações e realiza merge sem perda de dados.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  SupabaseClient get _client => Supabase.instance.client;
  // AuthService starts realtime while restoring its singleton. Reading that
  // singleton here would recursively construct it until the stack overflows.
  String? get _uid => _client.auth.currentUser?.id;

  bool get _canSync => SupabaseConfig.isConfigured && _uid != null;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Realiza sincronização completa bidirecional:
  /// 1. Sobe todas as palavras, histórico e favoritos locais para o Supabase
  /// 2. Baixa palavras, histórico e favoritos da nuvem que ainda não existem localmente
  Future<void> syncAll({VoidCallback? onComplete}) async {
    if (!_canSync || _isSyncing) return;
    _isSyncing = true;
    try {
      debugPrint('[SyncService] Iniciando sincronização completa em segundo plano...');
      await _syncWords();
      await _syncTracksAndFavorites();
      debugPrint('[SyncService] Sincronização completa finalizada com sucesso.');
      onComplete?.call();
    } catch (e) {
      debugPrint('[SyncService] Erro em syncAll: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncWords() async {
    if (!_canSync) return;
    final repo = KnownWordsRepository();
    final localWords = await repo.getKnownWordsList();

    // 1. PUSH: Envia palavras locais em lotes de 500 para o Supabase em paralelo
    if (localWords.isNotEmpty) {
      const chunkSize = 500;
      final futures = <Future<dynamic>>[];
      for (var i = 0; i < localWords.length; i += chunkSize) {
        final end = (i + chunkSize < localWords.length)
            ? i + chunkSize
            : localWords.length;
        final chunk = localWords.sublist(i, end).map((w) => {
              'user_id': _uid,
              'word': w.word,
              'normalized_word': w.normalizedWord,
              'language': w.language,
              'track_name': w.trackName,
              'artist_name': w.artistName,
              'created_at': w.createdAt.toIso8601String(),
            }).toList();

        futures.add(
          _client
              .from('known_words')
              .upsert(chunk, onConflict: 'user_id,normalized_word,language'),
        );
      }
      await Future.wait(futures);
    }

    // 2. PULL: Baixa palavras da nuvem com paginação (evita o limite padrão de 1000 do Supabase)
    const pageSize = 1000;
    var from = 0;
    final remoteRows = <Map<String, dynamic>>[];
    while (true) {
      final chunk = await _client
          .from('known_words')
          .select()
          .eq('user_id', _uid!)
          .range(from, from + pageSize - 1);
      remoteRows.addAll(chunk);
      if (chunk.length < pageSize) break;
      from += pageSize;
    }

    final localKeys =
        localWords.map((w) => '${w.normalizedWord}|${w.language}').toSet();

    final toInsert = <Map<String, dynamic>>[];
    for (final row in remoteRows) {
      final key = '${row['normalized_word']}|${row['language']}';
      if (!localKeys.contains(key)) {
        final rawDate = row['created_at'];
        int epochMs = DateTime.now().millisecondsSinceEpoch;
        if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null) epochMs = parsed.millisecondsSinceEpoch;
        } else if (rawDate is int) {
          epochMs = rawDate;
        }
        toInsert.add({
          'word': row['word'] as String,
          'normalized_word': row['normalized_word'] as String,
          'language': row['language'] as String,
          'track_name': row['track_name'] as String?,
          'artist_name': row['artist_name'] as String?,
          'created_at': epochMs,
        });
      }
    }

    if (toInsert.isNotEmpty) {
      final db = await AppDatabase().database;
      final batch = db.batch();
      for (final item in toInsert) {
        batch.insert(
          AppDatabase.tableKnownWords,
          item,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      KnownWordsRepository.notifyChanges();
      debugPrint('[SyncService] ${toInsert.length} novas palavras inseridas localmente.');
    }
  }

  Future<void> _syncTracksAndFavorites() async {
    if (!_canSync) return;
    await SavedTracks.instance.ready;

    final tracks = SavedTracks.instance.tracks;

    // 1. PUSH: Envia histórico e favoritos locais em lote (apenas 2 requests)
    if (tracks.isNotEmpty) {
      final tracksPayload = tracks.map((track) => {
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
          }).toList();

      final favIds = tracks
          .where((t) => SavedTracks.instance.isFavorite(t.id))
          .map((t) => t.id)
          .toList();

      final futures = <Future<dynamic>>[
        _client
            .from('history_tracks')
            .upsert(tracksPayload, onConflict: 'user_id,track_id'),
      ];

      if (favIds.isNotEmpty) {
        final favsPayload = favIds
            .map((id) => {'user_id': _uid, 'track_id': id})
            .toList();
        futures.add(
          _client
              .from('favorites')
              .upsert(favsPayload, onConflict: 'user_id,track_id'),
        );
      }

      await Future.wait(futures);
    }

    // 2. PULL: Baixa favoritos e histórico da nuvem e mescla em uma única operação
    final cloudFavorites = await pullFavorites();
    final existingTrackIds =
        SavedTracks.instance.tracks.map((t) => t.id).toSet();
    final newCloudTracks = await pullNewTracks(existingTrackIds);
    await SavedTracks.instance.mergeFromCloud(newCloudTracks, cloudFavorites);
  }

  // ───────────────────────────────────────────────────────────────
  // Palavras conhecidas (operações incrementais)
  // ───────────────────────────────────────────────────────────────

  /// Envia uma palavra para a nuvem (upsert por normalized_word + language).
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
    Set<String> existingKeys,
  ) async {
    if (!_canSync) return [];
    try {
      const pageSize = 1000;
      var from = 0;
      final rows = <Map<String, dynamic>>[];
      while (true) {
        final chunk = await _client
            .from('known_words')
            .select()
            .eq('user_id', _uid!)
            .range(from, from + pageSize - 1);
        rows.addAll(chunk);
        if (chunk.length < pageSize) break;
        from += pageSize;
      }
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
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
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
      const pageSize = 1000;
      var from = 0;
      final rows = <Map<String, dynamic>>[];
      while (true) {
        final chunk = await _client
            .from('favorites')
            .select('track_id')
            .eq('user_id', _uid!)
            .range(from, from + pageSize - 1);
        rows.addAll(chunk);
        if (chunk.length < pageSize) break;
        from += pageSize;
      }
      return rows.map((r) => r['track_id'] as String).toSet();
    } catch (e) {
      debugPrint('[SyncService] pullFavorites error: $e');
      return {};
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Supabase Realtime (Sincronização instantânea entre aparelhos)
  // ───────────────────────────────────────────────────────────────

  RealtimeChannel? _realtimeWordsChannel;
  RealtimeChannel? _realtimeFavoritesChannel;

  /// Inicia os listeners em tempo real para sincronização instantânea.
  void startRealtime() {
    if (!_canSync) return;
    final uid = _uid;
    if (uid == null) return;

    stopRealtime();

    try {
      debugPrint('[SyncService Realtime] Iniciando listeners em tempo real para o usuário $uid');

      // 1. Canal para palavras conhecidas
      _realtimeWordsChannel = _client.channel('public:known_words:$uid');
      _realtimeWordsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'known_words',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) async {
              debugPrint('[SyncService Realtime] Evento recebido em known_words: ${payload.eventType}');
              await _handleRealtimeWordEvent(payload);
            },
          )
          .subscribe();

      // 2. Canal para favoritos
      _realtimeFavoritesChannel = _client.channel('public:favorites:$uid');
      _realtimeFavoritesChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'favorites',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) async {
              debugPrint('[SyncService Realtime] Evento recebido em favorites: ${payload.eventType}');
              await _handleRealtimeFavoriteEvent(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SyncService Realtime] Erro ao iniciar realtime: $e');
    }
  }

  /// Cancela os canais em tempo real.
  void stopRealtime() {
    try {
      if (_realtimeWordsChannel != null) {
        _client.removeChannel(_realtimeWordsChannel!);
        _realtimeWordsChannel = null;
      }
      if (_realtimeFavoritesChannel != null) {
        _client.removeChannel(_realtimeFavoritesChannel!);
        _realtimeFavoritesChannel = null;
      }
    } catch (e) {
      debugPrint('[SyncService Realtime] Erro ao parar realtime: $e');
    }
  }

  Future<void> _handleRealtimeWordEvent(PostgresChangePayload payload) async {
    try {
      final db = await AppDatabase().database;
      if (payload.eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final normalized = oldRecord['normalized_word'] as String?;
        final language = oldRecord['language'] as String?;
        if (normalized != null && language != null) {
          final count = await db.delete(
            AppDatabase.tableKnownWords,
            where: 'normalized_word = ? AND language = ?',
            whereArgs: [normalized, language],
          );
          if (count > 0) {
            KnownWordsRepository.notifyChanges();
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final word = (newRecord['word'] as String? ?? '').trim();
          final normalized =
              (newRecord['normalized_word'] as String? ?? word.toLowerCase()).trim();
          final language = (newRecord['language'] as String? ?? 'en').trim();
          final trackName = newRecord['track_name'] as String?;
          final artistName = newRecord['artist_name'] as String?;
          final rawDate = newRecord['created_at'];
          int epochMs = DateTime.now().millisecondsSinceEpoch;
          if (rawDate is String) {
            final parsed = DateTime.tryParse(rawDate);
            if (parsed != null) epochMs = parsed.millisecondsSinceEpoch;
          } else if (rawDate is int) {
            epochMs = rawDate;
          }

          await db.insert(
            AppDatabase.tableKnownWords,
            {
              'word': word,
              'normalized_word': normalized,
              'language': language,
              'track_name': trackName,
              'artist_name': artistName,
              'created_at': epochMs,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          KnownWordsRepository.notifyChanges();
        }
      }
    } catch (e) {
      debugPrint('[SyncService Realtime] Erro ao processar evento de palavra: $e');
    }
  }

  Future<void> _handleRealtimeFavoriteEvent(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final trackId = payload.oldRecord['track_id'] as String?;
        if (trackId != null) {
          await SavedTracks.instance.setFavoriteRemote(trackId, false);
        }
      } else if (payload.eventType == PostgresChangeEvent.insert) {
        final trackId = payload.newRecord['track_id'] as String?;
        if (trackId != null) {
          await SavedTracks.instance.setFavoriteRemote(trackId, true);
        }
      }
    } catch (e) {
      debugPrint('[SyncService Realtime] Erro ao processar evento de favorito: $e');
    }
  }
}

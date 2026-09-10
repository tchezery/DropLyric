import 'spotify_session.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Serviço de reprodução de áudio com ValueNotifiers reativos.
///
/// Usa `just_audio` que funciona corretamente em todas as plataformas
/// (iOS, Android, macOS, Web) sem exibir elementos HTML visíveis.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<PlayerState> playerState = ValueNotifier(
    PlayerState(false, ProcessingState.idle),
  );
  final ValueNotifier<String?> currentUrl = ValueNotifier(null);
  final ValueNotifier<LoopMode> loopMode = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> shuffleMode = ValueNotifier(false);

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool get _isSpotify => currentUrl.value?.startsWith('spotify:track:') == true;
  final ValueNotifier<String?> error = ValueNotifier(null);
  bool _disposed = false;
  void _spotifyChanged() {
    if (_disposed || !_isSpotify) return;
    final session = SpotifySession.instance;
    error.value = session.error.isEmpty ? null : session.error;
    if (session.uri != currentUrl.value) {
      position.value = Duration.zero;
      if (playerState.value.playing ||
          playerState.value.processingState != ProcessingState.idle) {
        playerState.value = PlayerState(false, ProcessingState.idle);
      }
      return;
    }
    position.value = session.position;
    duration.value = session.duration;
    if (playerState.value.playing != !session.paused ||
        playerState.value.processingState != ProcessingState.ready) {
      playerState.value = PlayerState(!session.paused, ProcessingState.ready);
    }
  }

  AudioPlayerService() {
    SpotifySession.instance.playbackChanges.addListener(_spotifyChanged);
    _subscriptions.add(
      _player
          .createPositionStream(
            minPeriod: const Duration(milliseconds: 50),
            maxPeriod: const Duration(milliseconds: 50),
          )
          .listen((pos) {
            if (!_isSpotify && !_disposed) position.value = pos;
          }),
    );

    _subscriptions.add(
      _player.durationStream.listen((dur) {
        if (!_isSpotify && !_disposed && dur != null) duration.value = dur;
      }),
    );

    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (!_isSpotify && !_disposed) playerState.value = state;
      }),
    );

    _subscriptions.add(
      _player.loopModeStream.listen((mode) {
        if (!_disposed) loopMode.value = mode;
      }),
    );
  }

  /// Retorna `true` se o áudio está tocando.
  bool get isPlaying =>
      _isSpotify ? playerState.value.playing : _player.playing;

  /// Carrega e toca uma URL ou Asset. Se for a mesma faixa pausada, retoma.
  Future<void> play(String url) async {
    try {
      error.value = null;
      if (url.startsWith('spotify:track:')) {
        currentUrl.value = url;
        playerState.value = PlayerState(false, ProcessingState.loading);
        await _player.pause();
        await SpotifySession.instance.command('play', url);
        return;
      }
      if (currentUrl.value == url) {
        if (!_player.playing) {
          await _player.play();
        }
        return;
      }

      currentUrl.value = url;
      if (url.startsWith('assets/')) {
        try {
          await _player.setAsset(url);
        } catch (e) {
          debugPrint('AudioPlayerService setAsset error ($e), trying fallback');
          if (url.contains('shape_of_you')) {
            await _player.setUrl(
              'https://dn710705.ca.archive.org/0/items/JhePlalist/Ed%20Sheeran%20-%20Shape%20of%20You%20%5BOfficial%20Video%5D.mp3',
            );
          } else {
            await _player.setUrl(url);
          }
        }
      } else {
        await _player.setUrl(url);
      }
      await _player.play();
    } catch (e) {
      if (!_disposed) {
        error.value = 'Não foi possível tocar. Confira a conexão Spotify e tente novamente.';
        playerState.value = PlayerState(false, ProcessingState.idle);
      }
    }
  }

  /// Pausa a reprodução.
  Future<void> pause() async {
    if (_isSpotify) {
      await SpotifySession.instance.command('pause');
      return;
    }
    await _player.pause();
  }

  /// Alterna entre play e pause.
  Future<void> togglePlayPause(String url) async {
    if (isPlaying) {
      await pause();
    } else {
      await play(url);
    }
  }

  /// Move para uma posição específica.
  Future<void> seekTo(Duration pos) async {
    if (_isSpotify) {
      await SpotifySession.instance.command(
        'seek',
        pos.inMilliseconds.toString(),
      );
      return;
    }
    final end = _player.duration;
    final target = pos.isNegative
        ? Duration.zero
        : end != null && pos > end
        ? end
        : pos;
    await _player.seek(target);
  }

  /// Alterna entre: LoopMode.off -> LoopMode.all -> LoopMode.one -> LoopMode.off
  Future<void> toggleLoopMode() async {
    final current = loopMode.value;
    final next = current == LoopMode.off
        ? LoopMode.all
        : current == LoopMode.all
        ? LoopMode.one
        : LoopMode.off;
    loopMode.value = next;
    try {
      await _player.setLoopMode(next);
    } catch (_) {}
  }

  /// Alterna o modo aleatório
  void toggleShuffleMode() {
    shuffleMode.value = !shuffleMode.value;
  }

  /// Para e reseta.
  Future<void> stop() async {
    await _player.stop();
    position.value = Duration.zero;
    duration.value = Duration.zero;
    currentUrl.value = null;
  }

  /// Libera todos os recursos.
  Future<void> dispose() async {
    _disposed = true;
    SpotifySession.instance.playbackChanges.removeListener(_spotifyChanged);
    if (_isSpotify) {
      try {
        await SpotifySession.instance.command('pause');
      } catch (_) {}
    }
    error.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    position.dispose();
    duration.dispose();
    playerState.dispose();
    currentUrl.dispose();
    loopMode.dispose();
    shuffleMode.dispose();
  }
}

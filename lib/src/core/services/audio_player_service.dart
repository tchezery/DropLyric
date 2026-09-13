import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track_model.dart';
import 'spotify_service.dart';
import 'spotify_session.dart';

/// Reprodução exclusivamente Spotify.
class AudioPlayerService {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<PlayerState> playerState = ValueNotifier(
    PlayerState(false, ProcessingState.idle),
  );
  final ValueNotifier<String?> currentUrl = ValueNotifier(null);
  final ValueNotifier<LoopMode> loopMode = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> shuffleMode = ValueNotifier(false);

  bool get _isSpotify => currentUrl.value?.startsWith('spotify:track:') == true;
  final ValueNotifier<String?> error = ValueNotifier(null);
  bool _disposed = false;
  void _spotifyChanged() {
    if (_disposed || !_isSpotify) return;
    final session = SpotifySession.instance;
    error.value = session.error.isEmpty ? null : session.error;
    if (session.state['ready'] != true) {
      playerState.value = PlayerState(
        false,
        session.error.isEmpty ? ProcessingState.loading : ProcessingState.idle,
      );
      return;
    }
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
  }

  bool get isPlaying => playerState.value.playing;

  void syncSpotifyTrack(String uri) {
    currentUrl.value = uri;
    _spotifyChanged();
  }

  bool get _playbackSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> play(String url, {TrackModel? track}) async {
    error.value = null;
    final uri = SpotifyService.playbackUri(url, track: track);
    if (uri == null) {
      error.value = 'This track does not have a valid Spotify identifier.';
      return;
    }
    if (!SpotifySession.instance.connected) {
      error.value = 'Connect your Spotify account to play music.';
      return;
    }
    if (!_playbackSupported) {
      error.value = 'Spotify playback is not available on this platform.';
      playerState.value = PlayerState(false, ProcessingState.idle);
      return;
    }
    try {
      currentUrl.value = uri;
      position.value = Duration.zero;
      duration.value = Duration.zero;
      playerState.value = PlayerState(false, ProcessingState.loading);
      await SpotifySession.instance.command('play', uri);
      // O App Remote confirma o comando antes de emitir o próximo estado do
      // player. Atualiza a UI imediatamente; os eventos do Spotify corrigem
      // o estado caso a reprodução falhe ou seja pausada.
      _spotifyChanged();
      playerState.value = PlayerState(true, ProcessingState.ready);
    } catch (e) {
      if (!_disposed) {
        error.value = SpotifySession.instance.error.isNotEmpty
            ? SpotifySession.instance.error
            : e.toString();
        playerState.value = PlayerState(false, ProcessingState.idle);
      }
    }
  }

  Future<void> pause() async {
    if (_isSpotify && _playbackSupported) {
      await SpotifySession.instance.command('pause');
      playerState.value = PlayerState(false, ProcessingState.ready);
    }
  }

  Future<void> togglePlayPause(String url, {TrackModel? track}) async {
    if (isPlaying) {
      await pause();
    } else {
      await play(url, track: track);
    }
  }

  Future<void> seekTo(Duration pos) async {
    if (!_isSpotify || !_playbackSupported) return;
    final milliseconds = pos.inMilliseconds.clamp(
      0,
      duration.value.inMilliseconds,
    );
    await SpotifySession.instance.command('seek', milliseconds.toString());
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
  }

  /// Alterna o modo aleatório
  void toggleShuffleMode() {
    shuffleMode.value = !shuffleMode.value;
  }

  /// Para e reseta.
  Future<void> stop() async {
    await pause();
    playerState.value = PlayerState(false, ProcessingState.idle);
    position.value = Duration.zero;
    duration.value = Duration.zero;
    currentUrl.value = null;
  }

  /// Libera todos os recursos.
  Future<void> dispose() async {
    _disposed = true;
    SpotifySession.instance.playbackChanges.removeListener(_spotifyChanged);
    error.dispose();
    position.dispose();
    duration.dispose();
    playerState.dispose();
    currentUrl.dispose();
    loopMode.dispose();
    shuffleMode.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track_model.dart';
import 'spotify_service.dart';
import 'spotify_session.dart';

/// Serviço universal de reprodução de áudio (Direct Streams e Spotify).
class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<PlayerState> playerState = ValueNotifier(
    PlayerState(false, ProcessingState.idle),
  );
  final ValueNotifier<String?> currentUrl = ValueNotifier(null);
  final ValueNotifier<LoopMode> loopMode = ValueNotifier(LoopMode.off);
  final ValueNotifier<bool> shuffleMode = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  bool get isSpotify => currentUrl.value?.startsWith('spotify:track:') == true;
  bool get isDirectAudio =>
      currentUrl.value != null &&
      (currentUrl.value!.startsWith('http://') ||
          currentUrl.value!.startsWith('https://'));
  bool get _isSpotify => isSpotify;
  bool get _isDirectAudio => isDirectAudio;

  bool _disposed = false;
  final List<StreamSubscription> _subscriptions = [];

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

    _subscriptions.add(
      _audioPlayer.positionStream.listen((pos) {
        if (!_disposed && _isDirectAudio) {
          position.value = pos;
        }
      }),
    );

    _subscriptions.add(
      _audioPlayer.durationStream.listen((dur) {
        if (!_disposed && _isDirectAudio && dur != null) {
          duration.value = dur;
        }
      }),
    );

    _subscriptions.add(
      _audioPlayer.playerStateStream.listen((state) {
        if (!_disposed && _isDirectAudio) {
          playerState.value = state;
        }
      }),
    );

    _subscriptions.add(
      _audioPlayer.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          if (!_disposed) {
            debugPrint('Playback event error: $e');
            error.value = 'Playback error: $e';
          }
        },
      ),
    );
  }

  bool get isPlaying => playerState.value.playing;

  void syncSpotifyTrack(String uri) {
    currentUrl.value = uri;
    _spotifyChanged();
  }

  bool get _playbackSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> play(String url, {TrackModel? track}) async {
    error.value = null;

    // 1. YouTube tracks are audiovisual and handled via YoutubePlayer (iframe) in UI
    if (url.startsWith('youtube:') || (track?.id.startsWith('youtube:') == true)) {
      final videoKey = url.startsWith('youtube:') ? url : track!.id;
      currentUrl.value = videoKey;
      position.value = Duration.zero;
      duration.value = track?.duration != null
          ? Duration(milliseconds: (track!.duration! * 1000).round())
          : Duration.zero;
      playerState.value = PlayerState(false, ProcessingState.idle);
      return;
    }

    // 2. Direct HTTP Audio Stream (Previews, MP3s)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      currentUrl.value = url;
      position.value = Duration.zero;
      duration.value = Duration.zero;
      playerState.value = PlayerState(false, ProcessingState.loading);

      try {
        final dur = await _audioPlayer.setUrl(url);
        if (dur != null) {
          duration.value = dur;
        }
        if (_disposed) return;
        await _audioPlayer.play();
      } catch (e) {
        if (!_disposed) {
          error.value = 'Playback error: $e';
          playerState.value = PlayerState(false, ProcessingState.idle);
        }
      }
      return;
    }

    // 3. Spotify App Remote Playback
    final uri = SpotifyService.playbackUri(url, track: track);
    if (uri == null) {
      error.value = 'This track does not have a valid Spotify identifier.';
      return;
    }
    if (!SpotifySession.instance.remoteOnly &&
        !SpotifySession.instance.connected) {
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
      if (_disposed) return;
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
    try {
      if (_isDirectAudio) {
        await _audioPlayer.pause();
      } else if (_isSpotify && _playbackSupported) {
        if (SpotifySession.instance.connected) {
          await SpotifySession.instance.command('pause');
        }
        playerState.value = PlayerState(false, ProcessingState.ready);
      }
    } catch (e) {
      debugPrint('AudioPlayerService pause error: $e');
    }
  }

  Future<void> togglePlayPause(String url, {TrackModel? track}) async {
    if (isPlaying) {
      await pause();
    } else {
      if (_isDirectAudio &&
          _audioPlayer.audioSource != null &&
          currentUrl.value == (url.startsWith('youtube:') ? url : track?.id)) {
        try {
          await _audioPlayer.play();
        } catch (e) {
          debugPrint('AudioPlayerService resume error: $e');
          await play(url, track: track);
        }
      } else {
        await play(url, track: track);
      }
    }
  }

  Future<void> seekTo(Duration pos) async {
    try {
      if (_isDirectAudio) {
        if (_audioPlayer.audioSource != null) {
          await _audioPlayer.seek(pos);
        }
      } else if (_isSpotify && _playbackSupported) {
        if (SpotifySession.instance.connected) {
          final milliseconds = pos.inMilliseconds.clamp(
            0,
            duration.value.inMilliseconds,
          );
          await SpotifySession.instance.command('seek', milliseconds.toString());
        }
      }
    } catch (e) {
      debugPrint('AudioPlayerService seekTo error: $e');
    }
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
    if (_isDirectAudio) {
      try {
        await _audioPlayer.setLoopMode(next);
      } catch (e) {
        debugPrint('AudioPlayerService toggleLoopMode error: $e');
      }
    }
  }

  /// Alterna o modo aleatório
  void toggleShuffleMode() {
    shuffleMode.value = !shuffleMode.value;
  }

  /// Para e reseta.
  Future<void> stop() async {
    await pause();
    if (_isDirectAudio) {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('AudioPlayerService stop error: $e');
      }
    }
    playerState.value = PlayerState(false, ProcessingState.idle);
    position.value = Duration.zero;
    duration.value = Duration.zero;
    currentUrl.value = null;
  }

  /// Libera todos os recursos.
  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    SpotifySession.instance.playbackChanges.removeListener(_spotifyChanged);
    await _audioPlayer.dispose();
    error.dispose();
    position.dispose();
    duration.dispose();
    playerState.dispose();
    currentUrl.dispose();
    loopMode.dispose();
    shuffleMode.dispose();
  }
}


import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/models/track_model.dart';
import 'package:droplyric/src/core/services/spotify_service.dart';

void main() {
  const uri = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3';
  test('Spotify identity wins over a stale external audio URL', () {
    const track = TrackModel(
      id: uri,
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: 'Divide',
      previewAudioUrl: 'https://example.com/preview.m4a',
    );
    expect(
      SpotifyService.playbackUri(track.previewAudioUrl!, track: track),
      uri,
    );
  });
  test('external streams and local audio cannot be played', () {
    for (final source in [
      'https://example.com/full.mp3',
      'assets/audio/song.mp3',
      'spotify:track:invalid',
    ]) {
      expect(SpotifyService.playbackUri(source), isNull);
    }
  });
  test(
    'legacy tracks can use their exact Spotify link without a catalog search',
    () {
      const track = TrackModel(
        id: 'legacy',
        title: 'Song',
        artist: 'Artist',
        album: '',
        spotifyUrl: 'https://open.spotify.com/track/7qiZfU4dY1lWllzX7mPBI3',
      );
      expect(SpotifyService.playbackUri('', track: track), uri);
    },
  );
  test('home catalog contains only exact Spotify playback sources', () {
    for (final track in SpotifyService.curatedTracks) {
      expect(
        SpotifyService.playbackUri(track.previewAudioUrl!, track: track),
        track.id,
      );
      expect(track.previewAudioUrl, track.id);
    }
  });
}

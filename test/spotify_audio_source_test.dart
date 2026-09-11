import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/models/track_model.dart';
import 'package:droplyric/src/core/services/spotify_service.dart';

void main() {
  test('Spotify tracks retain their source instead of another catalog recording', () async {
    const uri = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3';
    final service = SpotifyService();
    for (final audio in [uri, 'https://example.com/preview.m4a']) {
      final track = TrackModel(
        id: uri,
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: 'Divide',
        previewAudioUrl: audio,
      );
      expect(await service.fetchFullAudioStream(track), same(track));
    }
  });
}

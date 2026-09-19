import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droplyric/src/core/models/track_model.dart';
import 'package:droplyric/src/core/services/saved_tracks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'history deduplicates and favorites survive restart and metadata updates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final saved = SavedTracks();
      const track = TrackModel(
        id: 'spotify:track:7qiZfU4dY1lWllzX7mPBI3',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
      );
      await saved.remember(track);
      await saved.toggleFavorite(track);
      await saved.remember(track.copyWith(title: 'Updated'));
      final restored = SavedTracks();
      await restored.ready;
      expect(restored.tracks.single.title, 'Updated');
      expect(restored.isFavorite(track.id), isTrue);
      await restored.toggleFavorite(restored.tracks.single);
      final restarted = SavedTracks();
      await restarted.ready;
      expect(restarted.isFavorite(track.id), isFalse);
      expect(restarted.tracks, hasLength(1));
      saved.dispose();
      restored.dispose();
      restarted.dispose();
    },
  );
  test('placeholder metadata is never added to history', () async {
    SharedPreferences.setMockInitialValues({});
    final saved = SavedTracks();
    await saved.remember(
      const TrackModel(id: 'id', title: '', artist: '', album: ''),
    );
    expect(saved.tracks, isEmpty);
    saved.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/models/known_word_model.dart';
import 'package:droplyric/src/core/models/learning_summary.dart';
import 'package:droplyric/src/core/models/track_model.dart';

void main() {
  test('ranks vocabulary and skips ambiguous legacy artist attribution', () {
    KnownWordModel word(
      String text, {
      String language = 'en',
      String? artist,
      String? song,
    }) => KnownWordModel(
      word: text,
      normalizedWord: text,
      language: language,
      artistName: artist,
      trackName: song,
      createdAt: DateTime(2026),
    );
    final summary = LearningSummary(
      [
        word('one', artist: 'Queen'),
        word('two', artist: 'Queen'),
        word('three', song: 'Unique'),
        word('four', song: 'Shared'),
        word('cinco', language: 'pt', artist: 'ABBA'),
        word('six', artist: 'Coldplay'),
      ],
      const [
        TrackModel(id: '1', title: 'Unique', artist: 'Queen', album: ''),
        TrackModel(id: '2', title: 'Shared', artist: 'Wrong A', album: ''),
        TrackModel(id: '3', title: 'Shared', artist: 'Wrong B', album: ''),
      ],
    );
    expect(summary.languages.first.key, 'en');
    expect(summary.languages.first.value, 5);
    expect(summary.artists.map((entry) => entry.key), [
      'Queen',
      'ABBA',
      'Coldplay',
    ]);
    expect(summary.artists.first.value, 3);
    expect(LearningSummary([], []).artists, isEmpty);
  });
}

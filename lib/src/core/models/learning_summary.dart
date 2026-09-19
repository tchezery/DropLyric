import 'known_word_model.dart';
import 'track_model.dart';

class LearningSummary {
  final List<MapEntry<String, int>> languages;
  final List<MapEntry<String, int>> artists;

  LearningSummary(List<KnownWordModel> words, List<TrackModel> tracks)
    : languages = _rank(_languages(words)),
      artists = _rank(_artists(words, tracks)).take(3).toList();

  static List<MapEntry<String, int>> _rank(Map<String, int> counts) =>
      counts.entries.toList()..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count != 0 ? count : a.key.compareTo(b.key);
      });

  static Map<String, int> _languages(List<KnownWordModel> words) {
    final counts = <String, int>{};
    for (final word in words) {
      counts.update(word.language, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static Map<String, int> _artists(
    List<KnownWordModel> words,
    List<TrackModel> tracks,
  ) {
    final byTitle = <String, Set<String>>{};
    for (final track in tracks) {
      if (track.artist.trim().isEmpty) continue;
      byTitle
          .putIfAbsent(track.title.trim().toLowerCase(), () => {})
          .add(track.artist.trim());
    }
    final counts = <String, int>{};
    for (final word in words) {
      var artist = word.artistName?.trim();
      if (artist == null || artist.isEmpty) {
        final matches = byTitle[word.trackName?.trim().toLowerCase()];
        artist = matches?.length == 1 ? matches!.single : null;
      }
      if (artist == null || artist.isEmpty) continue;
      counts.update(artist, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

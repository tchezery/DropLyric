/// Modelo de dados de uma faixa musical.
class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final String? previewAudioUrl;
  final String? spotifyUrl;
  final double? duration;
  final String language; // BCP-47, ex: "en", "es", "fr", "pt"

  const TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    this.previewAudioUrl,
    this.spotifyUrl,
    this.duration,
    // Empty means unknown: the player will detect the language from the lyrics.
    this.language = '',
  });

  TrackModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    String? previewAudioUrl,
    String? spotifyUrl,
    double? duration,
    String? language,
  }) {
    return TrackModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      previewAudioUrl: previewAudioUrl ?? this.previewAudioUrl,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      duration: duration ?? this.duration,
      language: language ?? this.language,
    );
  }

  @override
  String toString() =>
      'TrackModel(id: $id, title: $title, artist: $artist, language: $language)';
}

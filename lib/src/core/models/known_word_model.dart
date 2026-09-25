/// Entidade que representa uma palavra conhecida salva no banco de dados.
class KnownWordModel {
  final int? id;
  final String word;
  final String normalizedWord;
  final String language;
  final String? trackName;
  final String? artistName;
  final DateTime createdAt;

  const KnownWordModel({
    this.id,
    required this.word,
    required this.normalizedWord,
    required this.language,
    this.trackName,
    this.artistName,
    required this.createdAt,
  });

  factory KnownWordModel.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at'];
    final DateTime createdAt;
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return KnownWordModel(
      id: map['id'] as int?,
      word: (map['word'] as String?) ?? '',
      normalizedWord: (map['normalized_word'] as String?) ?? '',
      language: (map['language'] as String?) ?? '',
      trackName: map['track_name'] as String?,
      artistName: map['artist_name'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'normalized_word': normalizedWord,
      'language': language,
      'track_name': trackName,
      'artist_name': artistName,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() => 'KnownWordModel(word: $word, language: $language)';
}

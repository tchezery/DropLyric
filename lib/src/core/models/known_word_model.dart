/// Entidade que representa uma palavra conhecida salva no banco de dados.
class KnownWordModel {
  final int? id;
  final String word;
  final String normalizedWord;
  final String language;
  final String? trackName;
  final DateTime createdAt;

  const KnownWordModel({
    this.id,
    required this.word,
    required this.normalizedWord,
    required this.language,
    this.trackName,
    required this.createdAt,
  });

  factory KnownWordModel.fromMap(Map<String, dynamic> map) {
    return KnownWordModel(
      id: map['id'] as int?,
      word: map['word'] as String,
      normalizedWord: map['normalized_word'] as String,
      language: map['language'] as String,
      trackName: map['track_name'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'normalized_word': normalizedWord,
      'language': language,
      'track_name': trackName,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'KnownWordModel(word: $word, language: $language)';
}

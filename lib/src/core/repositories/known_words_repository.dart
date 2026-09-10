import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/known_word_model.dart';

/// Repositório responsável por todas as operações CRUD de palavras conhecidas no SQLite.
class KnownWordsRepository {
  final AppDatabase _appDatabase;

  KnownWordsRepository({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase();

  /// Alterna o estado de conhecimento de uma palavra:
  /// - Se já existir no banco, remove (desconhece).
  /// - Se não existir, insere (marca como conhecida).
  ///
  /// Retorna `true` se a palavra foi marcada como conhecida, `false` se foi removida.
  Future<bool> toggleWord(
    String word,
    String language, {
    String? trackName,
  }) async {
    final db = await _appDatabase.database;
    final normalized = word.toLowerCase().trim();

    final existing = await db.query(
      AppDatabase.tableKnownWords,
      where: 'normalized_word = ? AND language = ?',
      whereArgs: [normalized, language],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(
        AppDatabase.tableKnownWords,
        where: 'normalized_word = ? AND language = ?',
        whereArgs: [normalized, language],
      );
      return false;
    } else {
      final model = KnownWordModel(
        word: word.trim(),
        normalizedWord: normalized,
        language: language,
        trackName: trackName,
        createdAt: DateTime.now(),
      );
      await db.insert(
        AppDatabase.tableKnownWords,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    }
  }

  /// Retorna um `Set<String>` com todas as palavras normalizadas conhecidas
  /// para um idioma. Ideal para renderização rápida da letra.
  Future<Set<String>> getKnownWordsSet(String language) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableKnownWords,
      columns: ['normalized_word'],
      where: 'language = ?',
      whereArgs: [language],
    );
    return rows.map((r) => r['normalized_word'] as String).toSet();
  }

  /// Retorna a lista detalhada de palavras conhecidas, com suporte a
  /// filtragem por idioma e busca por termo.
  Future<List<KnownWordModel>> getKnownWordsList({
    String? language,
    String? query,
  }) async {
    final db = await _appDatabase.database;

    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (language != null && language.isNotEmpty) {
      whereParts.add('language = ?');
      whereArgs.add(language);
    }
    if (query != null && query.isNotEmpty) {
      whereParts.add('normalized_word LIKE ?');
      whereArgs.add('%${query.toLowerCase()}%');
    }

    final rows = await db.query(
      AppDatabase.tableKnownWords,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map(KnownWordModel.fromMap).toList();
  }

  /// Retorna o total de palavras conhecidas e um mapa de contagem por idioma.
  Future<({int total, Map<String, int> perLanguage})> getVocabularyStats() async {
    final db = await _appDatabase.database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppDatabase.tableKnownWords}',
    );
    final total = (totalResult.first['cnt'] as int?) ?? 0;

    final perLangResult = await db.rawQuery(
      'SELECT language, COUNT(*) as cnt FROM ${AppDatabase.tableKnownWords} GROUP BY language',
    );
    final perLanguage = <String, int>{
      for (final row in perLangResult)
        (row['language'] as String): (row['cnt'] as int? ?? 0),
    };

    return (total: total, perLanguage: perLanguage);
  }

  /// Remove uma palavra específica de um idioma.
  Future<void> removeWord(String normalizedWord, String language) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.tableKnownWords,
      where: 'normalized_word = ? AND language = ?',
      whereArgs: [normalizedWord, language],
    );
  }

  /// Remove todas as palavras de um idioma específico.
  Future<void> clearLanguage(String language) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.tableKnownWords,
      where: 'language = ?',
      whereArgs: [language],
    );
  }

  /// Verifica se uma palavra específica já é conhecida.
  Future<bool> isWordKnown(String normalizedWord, String language) async {
    final db = await _appDatabase.database;
    final result = await db.query(
      AppDatabase.tableKnownWords,
      where: 'normalized_word = ? AND language = ?',
      whereArgs: [normalizedWord, language],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}

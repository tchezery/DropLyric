import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/known_word_model.dart';
import '../services/sync_service.dart';

/// Repositório responsável por All as operações CRUD de palavras conhecidas no SQLite.
class KnownWordsRepository {
  final AppDatabase _appDatabase;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static Timer? _notifyDebounce;

  static void notifyChanges() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 150), () {
      changes.value++;
    });
  }

  KnownWordsRepository({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase();

  /// Ignore realtime echoes of local writes; only refresh views for new data.
  Future<bool> applyRemoteWord(KnownWordModel word) async {
    final db = await _appDatabase.database;
    final values = word.toMap()..remove('id');
    final changed = await db.transaction((txn) async {
      final existing = await txn.query(
        AppDatabase.tableKnownWords,
        where: 'normalized_word = ? AND language = ?',
        whereArgs: [word.normalizedWord, word.language],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert(AppDatabase.tableKnownWords, values);
        return true;
      }
      if (values.entries.every(
        (entry) => existing.single[entry.key] == entry.value,
      )) {
        return false;
      }
      await txn.update(
        AppDatabase.tableKnownWords,
        values,
        where: 'id = ?',
        whereArgs: [existing.single['id']],
      );
      return true;
    });
    if (changed) notifyChanges();
    return changed;
  }

  /// Grava o estado desejado, inclusive quando há vários toques em sequência.
  Future<void> setWordKnown(
    String word,
    String language,
    bool known, {
    String? trackName,
    String? artistName,
  }) async {
    final db = await _appDatabase.database;
    final normalized = word.toLowerCase().trim();
    if (!known) {
      await removeWord(normalized, language);
      return;
    }
    await db.insert(
      AppDatabase.tableKnownWords,
      KnownWordModel(
        word: word.trim(),
        normalizedWord: normalized,
        language: language,
        trackName: trackName,
        artistName: artistName,
        createdAt: DateTime.now(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    notifyChanges();
    // Sincroniza com a nuvem (silencioso, sem bloquear a UI)
    final model = KnownWordModel(
      word: word.trim(),
      normalizedWord: normalized,
      language: language,
      trackName: trackName,
      artistName: artistName,
      createdAt: DateTime.now(),
    );
    SyncService.instance.pushWord(model).ignore();
  }

  /// Grava o estado de conhecimento de múltiplas palavras de uma só vez (ex: frase inteira).
  Future<void> setWordsKnown(
    Iterable<String> words,
    String language,
    bool known, {
    String? trackName,
    String? artistName,
  }) async {
    final db = await _appDatabase.database;
    final batch = db.batch();
    final modelsToPush = <KnownWordModel>[];
    final wordsToDelete = <String>[];
    for (final word in words) {
      final normalized = word.toLowerCase().trim();
      if (normalized.isEmpty) continue;
      if (!known) {
        batch.delete(
          AppDatabase.tableKnownWords,
          where: 'normalized_word = ? AND language = ?',
          whereArgs: [normalized, language],
        );
        wordsToDelete.add(normalized);
      } else {
        final model = KnownWordModel(
          word: word.trim(),
          normalizedWord: normalized,
          language: language,
          trackName: trackName,
          artistName: artistName,
          createdAt: DateTime.now(),
        );
        modelsToPush.add(model);
        batch.insert(
          AppDatabase.tableKnownWords,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
    notifyChanges();
    for (final model in modelsToPush) {
      SyncService.instance.pushWord(model).ignore();
    }
    for (final norm in wordsToDelete) {
      SyncService.instance.deleteWord(norm, language).ignore();
    }
  }

  /// Alterna o estado de conhecimento de uma palavra:
  /// - Se já existir no banco, remove (desconhece).
  /// - Se não existir, insere (marca como conhecida).
  ///
  /// Retorna `true` se a palavra foi marcada como conhecida, `false` se foi removida.
  Future<bool> toggleWord(
    String word,
    String language, {
    String? trackName,
    String? artistName,
  }) async {
    final db = await _appDatabase.database;
    final normalized = word.toLowerCase().trim();
    KnownWordModel? insertedModel;

    final wasMarkedKnown = await db.transaction((txn) async {
      final existing = await txn.query(
        AppDatabase.tableKnownWords,
        where: 'normalized_word = ? AND language = ?',
        whereArgs: [normalized, language],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await txn.delete(
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
          artistName: artistName,
          createdAt: DateTime.now(),
        );
        insertedModel = model;
        await txn.insert(
          AppDatabase.tableKnownWords,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        return true;
      }
    });

    notifyChanges();

    if (wasMarkedKnown) {
      if (insertedModel != null) {
        SyncService.instance.pushWord(insertedModel!).ignore();
      }
    } else {
      SyncService.instance.deleteWord(normalized, language).ignore();
    }

    return wasMarkedKnown;
  }

  /// Retorna um `Set<String>` com All as palavras normalizadas conhecidas
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
  Future<({int total, Map<String, int> perLanguage})>
  getVocabularyStats() async {
    final db = await _appDatabase.database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppDatabase.tableKnownWords}',
    );
    final total = (totalResult.firstOrNull?['cnt'] as num?)?.toInt() ?? 0;

    final perLangResult = await db.rawQuery(
      'SELECT language, COUNT(*) as cnt FROM ${AppDatabase.tableKnownWords} GROUP BY language',
    );
    final perLanguage = <String, int>{
      for (final row in perLangResult)
        (row['language'] as String? ?? 'en'):
            ((row['cnt'] as num?)?.toInt() ?? 0),
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
    notifyChanges();
    SyncService.instance.deleteWord(normalizedWord, language).ignore();
  }

  Future<void> moveWord(String normalizedWord, String from, String to) async {
    final db = await _appDatabase.database;
    await db.update(
      AppDatabase.tableKnownWords,
      {'language': to},
      where: 'normalized_word = ? AND language = ?',
      whereArgs: [normalizedWord, from],
    );
  }

  /// Remove All as palavras de um idioma específico.
  Future<void> clearLanguage(String language) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.tableKnownWords,
      where: 'language = ?',
      whereArgs: [language],
    );
    notifyChanges();
  }

  Future<void> clearAll() async {
    final db = await _appDatabase.database;
    await db.delete(AppDatabase.tableKnownWords);
    notifyChanges();
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

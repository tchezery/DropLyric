import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:droplyric/src/core/database/app_database.dart';
import 'package:droplyric/src/core/models/known_word_model.dart';
import 'package:droplyric/src/core/repositories/known_words_repository.dart';

void main() {
  test('realtime echoes do not rewrite words or notify views', () async {
    sqfliteFfiInit();
    final database = AppDatabase.forTesting(
      (options) => databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: options,
      ),
    );
    addTearDown(database.close);
    final repository = KnownWordsRepository(appDatabase: database);
    KnownWordModel word({String? artist}) => KnownWordModel(
      word: 'Hello',
      normalizedWord: 'hello',
      language: 'en',
      artistName: artist,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1234),
    );
    expect(await repository.applyRemoteWord(word()), isTrue);
    final original = (await repository.getKnownWordsList()).single;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final revision = KnownWordsRepository.changes.value;
    for (var i = 0; i < 20; i++) {
      expect(await repository.applyRemoteWord(word()), isFalse);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(KnownWordsRepository.changes.value, revision);
    expect(await repository.applyRemoteWord(word(artist: 'Artist')), isTrue);
    final updated = (await repository.getKnownWordsList()).single;
    expect(updated.id, original.id);
    expect(updated.artistName, 'Artist');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(KnownWordsRepository.changes.value, revision + 1);
  });

  test('known words and removals persist after reopening SQLite', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('droplyric-words-');
    final path = '${directory.path}/words.db';
    AppDatabase open() => AppDatabase.forTesting(
      (options) => databaseFactoryFfi.openDatabase(path, options: options),
    );
    var database = open();
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    var repository = KnownWordsRepository(appDatabase: database);
    expect(
      await repository.toggleWord(
        ' Hello ',
        'en',
        trackName: 'Song',
        artistName: 'Artist',
      ),
      isTrue,
    );
    expect(await repository.toggleWord('hello', 'pt'), isTrue);
    await database.close();
    database = open();
    repository = KnownWordsRepository(appDatabase: database);
    expect(await repository.getKnownWordsSet('en'), {'hello'});
    final words = await repository.getKnownWordsList(language: 'en');
    expect(words.single.word, 'Hello');
    expect(words.single.trackName, 'Song');
    expect(words.single.artistName, 'Artist');
    expect((await repository.getVocabularyStats()).total, 2);
    expect(await repository.toggleWord('HELLO', 'en'), isFalse);
    await database.close();
    database = open();
    repository = KnownWordsRepository(appDatabase: database);
    expect(await repository.getKnownWordsSet('en'), isEmpty);
    expect(await repository.getKnownWordsSet('pt'), {'hello'});
    await repository.setWordKnown('World', 'en', true);
    await repository.setWordKnown('WORLD', 'en', true);
    expect(await repository.getKnownWordsSet('en'), {'world'});
    await repository.setWordKnown('world', 'en', false);
    await repository.setWordKnown('world', 'en', false);
    expect(await repository.getKnownWordsSet('en'), isEmpty);
    await Future.wait([
      repository.toggleWord('world', 'en'),
      repository.toggleWord('world', 'en'),
    ]);
    expect(await repository.getKnownWordsSet('en'), isEmpty);
  });
  test('upgrades existing vocabulary without losing words', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'droplyric-upgrade-',
    );
    final path = '${directory.path}/words.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE known_words (id INTEGER PRIMARY KEY, word TEXT NOT NULL, normalized_word TEXT NOT NULL, language TEXT NOT NULL, track_name TEXT, created_at INTEGER NOT NULL, UNIQUE(normalized_word, language))',
          );
          await db.insert('known_words', {
            'word': 'hello',
            'normalized_word': 'hello',
            'language': 'en',
            'track_name': 'Old song',
            'created_at': 1,
          });
        },
      ),
    );
    await old.close();
    final database = AppDatabase.forTesting(
      (options) => databaseFactoryFfi.openDatabase(path, options: options),
    );
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    final repository = KnownWordsRepository(appDatabase: database);
    final words = await repository.getKnownWordsList();
    expect(words.single.word, 'hello');
    expect(words.single.artistName, isNull);
    await repository.setWordKnown('new', 'en', true, artistName: 'Queen');
    await repository.setWordKnown('new', 'en', true, artistName: 'Other');
    expect((await repository.getKnownWordsList()).first.artistName, 'Queen');
  });
}

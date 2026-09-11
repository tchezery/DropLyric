import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:droplyric/src/core/database/app_database.dart';
import 'package:droplyric/src/core/repositories/known_words_repository.dart';

void main() {
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
      await repository.toggleWord(' Hello ', 'en', trackName: 'Song'),
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
}

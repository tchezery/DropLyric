import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/models/lyric_line_model.dart';
import 'package:droplyric/src/core/models/track_model.dart';
import 'package:droplyric/src/core/repositories/known_words_repository.dart';
import 'package:droplyric/src/core/services/language_service.dart';
import 'package:droplyric/src/core/services/lyrics_service.dart';
import 'package:droplyric/src/pages/player_page.dart';
import 'package:droplyric/src/widgets/lyrics/interactive_word.dart';
import 'package:droplyric/src/widgets/lyrics/language_selector_sheet.dart';

class DelayedLanguages extends LanguageService {
  final preference = Completer<String>();
  @override
  Future<String> getNativeLanguage() async => 'pt';
  @override
  Future<String> getTargetLanguage() => preference.future;
  @override
  Future<void> setNativeLanguage(String languageCode) async {}
  @override
  Future<void> setTargetLanguage(String languageCode) async {}
}

class MemoryWords extends KnownWordsRepository {
  final writes = <String>[];
  @override
  Future<Set<String>> getKnownWordsSet(String language) async => {};
  @override
  Future<void> setWordKnown(
    String word,
    String language,
    bool known, {
    String? trackName,
    String? artistName,
  }) async {
    writes.add('$language:${word.toLowerCase()}');
  }
}

void main() {
  const english =
      'You and I have a dream. We do what we love as the night begins.';
  test(
    'English markers beat shared Portuguese words and repeated refrains',
    () {
      expect(detectLyricLanguage(english), 'en');
      expect(detectLyricLanguage('a do as ' * 40 + english), 'en');
      expect(detectLyricLanguage("I don't know why you love the night"), 'en');
    },
  );
  test(
    'other languages remain detectable and ambiguous text is not guessed',
    () {
      expect(
        detectLyricLanguage('Eu quero você com meu coração e minha saudade'),
        'pt',
      );
      expect(
        detectLyricLanguage('Quiero la vida pero tengo amor con una canción'),
        'es',
      );
      expect(
        detectLyricLanguage('Dans la vie avec mon amour pour les rêves'),
        'fr',
      );
      expect(detectLyricLanguage('Ich liebe das Leben und die Nacht'), 'de');
      expect(detectLyricLanguage('Il mio amore per la vita non cambia'), 'it');
      expect(detectLyricLanguage('a do as a do as'), isNull);
      expect(detectLyricLanguage('amor vida'), isNull);
      expect(detectLyricLanguage(''), isNull);
    },
  );

  Future<void> openPlayer(
    WidgetTester tester,
    DelayedLanguages languages,
    MemoryWords words, {
    String trackLanguage = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          track: TrackModel(
            id: 'lrclib:test',
            title: 'Test song',
            artist: 'Test artist',
            album: '',
            language: trackLanguage,
          ),
          lyricsOnly: true,
          initialLyrics: LyricsResult(
            lines: LyricParser.parsePlain(english),
            isSynced: false,
            plainText: english,
          ),
          languageService: languages,
          wordsRepository: words,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'late PT preference cannot replace English or misfile saved words',
    (tester) async {
      final languages = DelayedLanguages();
      final words = MemoryWords();
      await openPlayer(tester, languages, words);
      expect(find.text('EN'), findsOneWidget);
      languages.preference.complete('pt');
      await tester.pumpAndSettle();
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('PT'), findsNothing);
      final word = find.byWidgetPredicate(
        (w) => w is InteractiveWord && w.word == 'dream',
      );
      await tester.tap(word);
      await tester.pumpAndSettle();
      expect(words.writes, ['en:dream']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'English lyrics override stale metadata but respect a manual selection',
    (tester) async {
      final languages = DelayedLanguages();
      final words = MemoryWords();
      await openPlayer(tester, languages, words, trackLanguage: 'pt');
      expect(find.text('EN'), findsOneWidget);
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      tester
          .widget<LanguageSelectorSheet>(find.byType(LanguageSelectorSheet))
          .onConfirm('pt', 'es');
      Navigator.of(tester.element(find.byType(LanguageSelectorSheet))).pop();
      await tester.pumpAndSettle();
      languages.preference.complete('pt');
      await tester.pumpAndSettle();
      expect(find.text('ES'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}

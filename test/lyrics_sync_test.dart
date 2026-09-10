import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/models/lyric_line_model.dart';

void main() {
  test('LRC aceita frações, múltiplos tempos, metadados e offset', () {
    final lines = LyricParser.parseLrc('''
[ar:Example]
[offset:-100]
[00:02.50][00:05.125] Verso repetido
[00:01] Primeiro
[00:03.2] Outro
[00:04.000]
[00:99.00] inválido
''');
    expect(lines.map((l) => l.timestamp.inMilliseconds), [
      900,
      2400,
      3100,
      3900,
      5025,
    ]);
    expect(lines.last.rawText, 'Verso repetido');
    expect(lines[3].isEmpty, isTrue);
  });

  test('acompanha introdução, fronteiras, pausas e busca para trás', () {
    final lines = LyricParser.parseLrc(
      '[00:02] Um\n[00:05] Dois\n[00:07]\n[00:09] Fim',
    );
    for (final entry in {
      0: -1,
      2000: 0,
      4999: 0,
      5000: 1,
      7000: 2,
      10000: 3,
      3000: 0,
    }.entries) {
      expect(
        LyricParser.activeLineAt(lines, Duration(milliseconds: entry.key)),
        entry.value,
      );
    }
    expect(LyricParser.activeLineAt([], Duration.zero), -1);
  });

  test('texto livre não inventa tempos', () {
    expect(
      LyricParser.parsePlain('Um\nDois')
          .every((line) => line.timestamp == Duration.zero),
      isTrue,
    );
  });

  test('pontuação, vírgulas, pontos e interrogações são estritamente isolados', () {
    final lines = LyricParser.parsePlain('Oh we could never, be together. Are you happy? Don\'t go!');
    final tokens = lines.first.words;

    // "never," deve ser palavra "never" seguida de pontuação ","
    final neverToken = tokens.firstWhere((t) => t.normalizedWord == 'never');
    expect(neverToken.displayText, 'never');
    expect(neverToken.isWord, isTrue);

    // "together." deve ser palavra "together" seguida de pontuação "."
    final togetherToken = tokens.firstWhere((t) => t.normalizedWord == 'together');
    expect(togetherToken.displayText, 'together');
    expect(togetherToken.isWord, isTrue);

    // "happy?" deve ser palavra "happy" seguida de pontuação "?"
    final happyToken = tokens.firstWhere((t) => t.normalizedWord == 'happy');
    expect(happyToken.displayText, 'happy');
    expect(happyToken.isWord, isTrue);

    // Contração "Don't" preserva apóstrofo interno
    final dontToken = tokens.firstWhere((t) => t.normalizedWord == 'don\'t');
    expect(dontToken.displayText, 'Don\'t');
    expect(dontToken.isWord, isTrue);

    // Pontuações não são palavras (isWord = false)
    final punctTokens = tokens.where((t) => !t.isWord).map((t) => t.displayText).toList();
    expect(punctTokens.any((t) => t.contains(',')), isTrue);
    expect(punctTokens.any((t) => t.contains('.')), isTrue);
    expect(punctTokens.any((t) => t.contains('?')), isTrue);
    expect(punctTokens.any((t) => t.contains('!')), isTrue);
  });
}

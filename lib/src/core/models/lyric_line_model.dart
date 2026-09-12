/// Modelo que representa uma linha de letra com timestamp (formato LRC).
class LyricLine {
  final Duration timestamp;
  final String rawText;
  final List<WordToken> words;

  const LyricLine({
    required this.timestamp,
    required this.rawText,
    required this.words,
  });

  bool get isEmpty => rawText.trim().isEmpty;
}

/// Token de uma palavra na letra, incluindo pontuação adjacente.
class WordToken {
  /// O texto exibido na tela (ex: "hello,").
  final String displayText;

  /// Apenas a palavra limpa, normalizada para busca no banco (ex: "hello").
  final String normalizedWord;

  /// Se é uma palavra real (true) ou apenas espaço/pontuação (false).
  final bool isWord;

  const WordToken({
    required this.displayText,
    required this.normalizedWord,
    required this.isWord,
  });
}

/// Parser de letras no formato LRC e texto simples.
class LyricParser {
  /// Parse de texto LRC com timestamps. Ex: `[01:23.45] Hello world`
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    final timestampRegex = RegExp(r'\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]');
    final offsetMatch = RegExp(
      r'\[offset:([+-]?\d+)\]',
      caseSensitive: false,
    ).firstMatch(lrcText);
    final offset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;

    for (final rawLine in lrcText.split('\n')) {
      final input = rawLine.trim();
      final matches = timestampRegex.allMatches(input).toList();
      if (matches.isEmpty || matches.first.start != 0) continue;
      final text = input.substring(matches.last.end).trim();
      for (final match in matches) {
        final seconds = int.parse(match.group(2)!);
        if (seconds >= 60) continue;
        final fraction = (match.group(3) ?? '').padRight(3, '0');
        lines.add(
          LyricLine(
            timestamp: Duration(
              minutes: int.parse(match.group(1)!),
              seconds: seconds,
              milliseconds: int.parse(fraction) + offset,
            ),
            rawText: text,
            words: _tokenize(text),
          ),
        );
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Última linha iniciada; -1 durante a introdução. Funciona também ao voltar.
  static int activeLineAt(List<LyricLine> lines, Duration position) {
    var low = 0;
    var high = lines.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (lines[middle].timestamp <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low - 1;
  }

  /// Parse de texto simples (sem timestamps) dividido por quebras de linha.
  static List<LyricLine> parsePlain(String plainText) {
    final lines = <LyricLine>[];
    final rawLines = plainText.split('\n');

    for (int i = 0; i < rawLines.length; i++) {
      final text = rawLines[i];
      lines.add(
        LyricLine(
          timestamp: Duration.zero, // texto sem sincronização
          rawText: text,
          words: _tokenize(text),
        ),
      );
    }

    return lines;
  }

  /// Tokeniza uma linha em palavras e pontuações/símbolos estritamente separados.
  /// Pontuações (pontos, vírgulas, interrogações, símbolos) NUNCA são mescladas
  /// na palavra, garantindo que não fiquem marcadas como conhecidas.
  static List<WordToken> _tokenize(String line) {
    if (line.trim().isEmpty) return [];

    final tokens = <WordToken>[];
    // Palavras com letras/acentos e possíveis apóstrofos internos (ex: "don't", "it's")
    final wordRegex = RegExp(
      r"[a-zA-ZÀ-ÿ\u0100-\u017F]+(?:['’][a-zA-ZÀ-ÿ\u0100-\u017F]+)*",
    );

    int lastEnd = 0;
    for (final match in wordRegex.allMatches(line)) {
      if (match.start > lastEnd) {
        final punct = line.substring(lastEnd, match.start);
        tokens.add(WordToken(
          displayText: punct,
          normalizedWord: punct,
          isWord: false,
        ));
      }
      final word = match.group(0)!;
      tokens.add(WordToken(
        displayText: word,
        normalizedWord: word.toLowerCase(),
        isWord: true,
      ));
      lastEnd = match.end;
    }
    if (lastEnd < line.length) {
      final trailing = line.substring(lastEnd);
      tokens.add(WordToken(
        displayText: trailing,
        normalizedWord: trailing,
        isWord: false,
      ));
    }

    return tokens;
  }
}

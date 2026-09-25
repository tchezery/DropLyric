import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'dictionary_service.dart';
import 'language_service.dart';
import 'lyrics_service.dart';
import 'saved_tracks.dart';

enum QuizFrequency {
  rare,
  regular,
  always,
}

class WordTranslationData {
  final String word;
  final String primaryTranslation;
  final List<String> allAcceptedTranslations;
  final List<String> topAlternativeMeanings;

  const WordTranslationData({
    required this.word,
    required this.primaryTranslation,
    required this.allAcceptedTranslations,
    required this.topAlternativeMeanings,
  });
}

class QuizQuestion {
  final String word;
  final String? trackName;
  final String? artistName;
  final String correctAnswer;
  final List<String> options;
  final List<String> allAcceptedTranslations;
  final bool isTypingMode;

  const QuizQuestion({
    required this.word,
    this.trackName,
    this.artistName,
    required this.correctAnswer,
    required this.options,
    required this.allAcceptedTranslations,
    required this.isTypingMode,
  });

  bool checkAnswer(String input) {
    return QuizService.validateAnswer(input, allAcceptedTranslations);
  }
}

class LyricFillQuestion {
  final String trackTitle;
  final String artistName;
  final String fullLine;
  final String lineWithBlank;
  final String targetWord;
  final String? wordTranslation;
  final String? lineTranslation;
  final String? lineTranslationWithBlank;

  const LyricFillQuestion({
    required this.trackTitle,
    required this.artistName,
    required this.fullLine,
    required this.lineWithBlank,
    required this.targetWord,
    this.wordTranslation,
    this.lineTranslation,
    this.lineTranslationWithBlank,
  });

  bool checkAnswer(String input) {
    return QuizService.normalize(input) == QuizService.normalize(targetWord);
  }
}

class QuizService {
  static final QuizService instance = QuizService._internal();
  QuizService._internal();

  final http.Client _client = http.Client();
  final Map<String, WordTranslationData> _cache = {};
  final Random _rng = Random();

  static const _keyQuizFrequency = 'quiz_frequency';
  QuizFrequency _frequency = QuizFrequency.regular;
  bool _frequencyLoaded = false;

  Future<QuizFrequency> getFrequency() async {
    if (_frequencyLoaded) return _frequency;
    try {
      final db = await AppDatabase().database;
      final rows = await db.query(
        AppDatabase.tablePreferences,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_keyQuizFrequency],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = rows.first['value'] as String?;
        if (val == 'always') {
          _frequency = QuizFrequency.always;
        } else if (val == 'rare' || val == 'low') {
          _frequency = QuizFrequency.rare;
        } else {
          _frequency = QuizFrequency.regular;
        }
      }
    } catch (_) {}
    _frequencyLoaded = true;
    return _frequency;
  }

  Future<void> setFrequency(QuizFrequency freq) async {
    _frequency = freq;
    _frequencyLoaded = true;
    try {
      final db = await AppDatabase().database;
      final valStr = freq == QuizFrequency.always
          ? 'always'
          : freq == QuizFrequency.rare
              ? 'rare'
              : 'regular';
      await db.insert(
        AppDatabase.tablePreferences,
        {'key': _keyQuizFrequency, 'value': valStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<bool> shouldTriggerQuizAsync() async {
    final freq = await getFrequency();
    switch (freq) {
      case QuizFrequency.always:
        return true;
      case QuizFrequency.regular:
        return _rng.nextDouble() < 0.70;
      case QuizFrequency.rare:
        return _rng.nextDouble() < 0.30;
    }
  }

  static const List<String> _distractorPool = [
    'tempo', 'caminho', 'janela', 'noite', 'escutar', 'amigo', 'sorriso',
    'verdade', 'silêncio', 'correr', 'abrir', 'lembrar', 'esquecer', 'olhar',
    'começar', 'esperar', 'sonho', 'chuva', 'vento', 'fogo', 'coração',
    'cidade', 'segredo', 'viagem', 'mundo', 'voz', 'passo', 'pensamento',
    'luz', 'sombra', 'espaço', 'estrela', 'frio', 'calor', 'porta', 'estrada',
    'encontrar', 'perder', 'vencer', 'mudar', 'acreditar', 'sentir', 'partir',
    'falar', 'entender', 'construir', 'dançar', 'amar', 'criar', 'vida',
  ];

  static String normalize(String str) {
    var s = str.trim().toLowerCase();
    const withAccents = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return s;
  }

  static bool validateAnswer(String input, List<String> acceptedMeanings) {
    final cleanInput = normalize(input);
    if (cleanInput.isEmpty) return false;
    for (final accepted in acceptedMeanings) {
      final cleanAccepted = normalize(accepted);
      if (cleanAccepted == cleanInput) return true;
      // Trata correspondência com artigos (ex: "o livro" vs "livro")
      if (cleanAccepted.startsWith('o ') || cleanAccepted.startsWith('a ')) {
        final stripped = cleanAccepted.substring(2).trim();
        if (stripped == cleanInput) return true;
      }
    }
    return false;
  }

  /// Busca tradução principal e significados alternativos completos (verbos, conjunções, substantivos, etc.)
  Future<WordTranslationData?> fetchTranslationData(
    String rawWord, {
    String sourceLang = 'auto',
    String targetLang = 'pt',
  }) async {
    final word = rawWord
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s'’-]", unicode: true), '')
        .trim();
    if (word.isEmpty) return null;

    final cacheKey = '${word.toLowerCase()}|$sourceLang|$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&dt=bd&q=${Uri.encodeComponent(word)}',
      );
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
        },
      ).timeout(const Duration(milliseconds: 2200));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? primary;
        final accepted = <String>{};
        final topCandidates = <String>[];

        // 1. Tradução primária
        if (data is List && data.isNotEmpty && data.first is List) {
          final parts = data.first as List;
          if (parts.isNotEmpty && parts.first is List) {
            final firstPart = parts.first as List;
            if (firstPart.isNotEmpty && firstPart.first is String) {
              primary = (firstPart.first as String).trim();
              if (primary.isNotEmpty) {
                accepted.add(primary.toLowerCase());
                topCandidates.add(primary);
              }
            }
          }
        }

        // 2. Extrai partes do discurso e seus significados alternativos
        if (data is List && data.length > 1 && data[1] is List) {
          final posList = data[1] as List;
          for (final posEntry in posList) {
            if (posEntry is List && posEntry.length > 1 && posEntry[1] is List) {
              final wordsList = posEntry[1] as List;
              for (int i = 0; i < wordsList.length; i++) {
                final w = wordsList[i].toString().trim();
                if (w.isNotEmpty) {
                  accepted.add(w.toLowerCase());
                  // Pega as primeiras alternativas de cada classe para enriquecer as opções do quiz
                  if (i < 2 && !topCandidates.map(normalize).contains(normalize(w))) {
                    topCandidates.add(w);
                  }
                }
              }
            }
          }
        }

        if (primary != null && primary.isNotEmpty) {
          final result = WordTranslationData(
            word: word,
            primaryTranslation: primary,
            allAcceptedTranslations: accepted.toList(),
            topAlternativeMeanings: topCandidates,
          );
          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {}

    // Fallback para DictionaryService padrão se GTX dt=bd falhar
    try {
      final fallback = await DictionaryService().translateText(
        word,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      if (fallback != null && fallback.trim().isNotEmpty) {
        final cleanFallback = fallback.trim();
        final result = WordTranslationData(
          word: word,
          primaryTranslation: cleanFallback,
          allAcceptedTranslations: [cleanFallback.toLowerCase()],
          topAlternativeMeanings: [cleanFallback],
        );
        _cache[cacheKey] = result;
        return result;
      }
    } catch (_) {}

    return null;
  }

  /// Gera uma pergunta dinâmica:
  /// - Pode selecionar uma tradução primária OU alternativa como correta (ex: "gostar" ou "como" para "like")
  /// - Cria 3 distratores plausíveis que não conflitam com nenhum dos significados aceitos
  /// - Alterna entre modo múltipla escolha e modo digitação
  QuizQuestion? generateQuestion({
    required WordTranslationData data,
    String? trackName,
    String? artistName,
    bool forceTyping = false,
    bool forceMultipleChoice = false,
  }) {
    if (data.allAcceptedTranslations.isEmpty) return null;

    final isTyping = forceTyping
        ? true
        : forceMultipleChoice
            ? false
            : _rng.nextBool();

    // Escolhe aleatoriamente uma das traduções candidatas válidas (ex: ora "como", ora "gostar")
    final candidates = data.topAlternativeMeanings.isNotEmpty
        ? data.topAlternativeMeanings
        : [data.primaryTranslation];
    final chosenCorrect = candidates[_rng.nextInt(candidates.length)];

    // Filtra distratores que não tenham nenhuma sobreposição com os significados aceitos da palavra
    final normalizedAccepted = data.allAcceptedTranslations.map(normalize).toSet();
    final availableDistractors = _distractorPool.where((d) {
      return !normalizedAccepted.contains(normalize(d));
    }).toList()..shuffle(_rng);

    final selectedDistractors = availableDistractors.take(3).toList();
    final options = <String>[chosenCorrect, ...selectedDistractors]..shuffle(_rng);

    return QuizQuestion(
      word: data.word,
      trackName: trackName,
      artistName: artistName,
      correctAnswer: chosenCorrect,
      options: options,
      allAcceptedTranslations: data.allAcceptedTranslations,
      isTypingMode: isTyping,
    );
  }

  /// Gera uma pergunta do minigame "Completar a frase da música":
  /// - Busca a letra de uma música do histórico do usuário (ou faixa especificada)
  /// - Encontra uma linha ideal e oculta uma palavra específica
  /// - Retorna a linha com lacuna e tradução de dica opcional
  Future<LyricFillQuestion?> generateLyricFillQuestion({
    String? trackTitle,
    String? artistName,
    List<String>? targetWords,
  }) async {
    final lyricsService = LyricsService();
    String? title = trackTitle;
    String? artist = artistName;

    if (title == null || artist == null || title.isEmpty || artist.isEmpty) {
      final savedTracks = SavedTracks.instance.tracks;
      if (savedTracks.isNotEmpty) {
        final pool = savedTracks.take(15).toList();
        final picked = pool[_rng.nextInt(pool.length)];
        title = picked.title;
        artist = picked.artist;
      } else {
        final defaults = [
          ('Yellow', 'Coldplay'),
          ('Let It Be', 'The Beatles'),
          ('Someone Like You', 'Adele'),
          ('Shape of You', 'Ed Sheeran'),
        ];
        final picked = defaults[_rng.nextInt(defaults.length)];
        title = picked.$1;
        artist = picked.$2;
      }
    }

    try {
      final lyrics = await lyricsService.getLyrics(
        trackName: title,
        artistName: artist,
      );
      if (lyrics == null || lyrics.lines.isEmpty) return null;

      final validLines = lyrics.lines.map((l) => l.rawText.trim()).where((text) {
        if (text.length < 15 || text.length > 85) return false;
        if (text.startsWith('[') || (text.startsWith('(') && text.endsWith(')'))) return false;
        final wordsCount = text.split(RegExp(r'\s+')).length;
        return wordsCount >= 3;
      }).toList();

      if (validLines.isEmpty) return null;

      String? chosenLine;
      String? chosenWord;

      if (targetWords != null && targetWords.isNotEmpty) {
        final shuffledLines = List<String>.from(validLines)..shuffle(_rng);
        for (final line in shuffledLines) {
          final wordsInLine = line
              .split(RegExp(r"[^\p{L}\p{N}'’-]", unicode: true))
              .map((w) => w.trim())
              .where((w) => w.isNotEmpty)
              .toList();

          for (final target in targetWords) {
            final match = wordsInLine.firstWhere(
              (w) => normalize(w) == normalize(target),
              orElse: () => '',
            );
            if (match.isNotEmpty && match.length >= 3) {
              chosenLine = line;
              chosenWord = match;
              break;
            }
          }
          if (chosenLine != null) break;
        }
      }

      if (chosenLine == null) {
        final shuffledLines = List<String>.from(validLines)..shuffle(_rng);
        const stopWords = {
          'the', 'and', 'that', 'this', 'with', 'from', 'they', 'will',
          'would', 'there', 'their', 'what', 'about', 'which', 'when',
          'like', 'time', 'just', 'know', 'take', 'into', 'your', 'some',
          'could', 'them', 'than', 'then', 'only', 'come', 'over', 'also',
          'para', 'com', 'que', 'não', 'uma', 'como', 'mais', 'mas',
        };

        for (final line in shuffledLines) {
          final candidates = line
              .split(RegExp(r"[^\p{L}\p{N}'’-]", unicode: true))
              .map((w) => w.trim())
              .where((w) => w.length >= 4 && !stopWords.contains(w.toLowerCase()))
              .toList();

          if (candidates.isNotEmpty) {
            chosenLine = line;
            chosenWord = candidates[_rng.nextInt(candidates.length)];
            break;
          }
        }
      }

      if (chosenLine == null || chosenWord == null) return null;

      final regex = RegExp(
        r'\b' + RegExp.escape(chosenWord) + r'\b',
        caseSensitive: false,
      );
      final blanked = chosenLine.replaceFirst(regex, '_______');

      final contextTrans = await fetchContextualWordTranslation(
        sentence: chosenLine,
        targetWord: chosenWord,
      );

      return LyricFillQuestion(
        trackTitle: title,
        artistName: artist,
        fullLine: chosenLine,
        lineWithBlank: blanked,
        targetWord: chosenWord,
        wordTranslation: contextTrans.wordTranslation,
        lineTranslation: contextTrans.lineTranslation,
        lineTranslationWithBlank: contextTrans.lineTranslationWithBlank,
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtém a tradução contextual da palavra inserida dentro da frase da música.
  /// Envia a frase com marcadores neurais [palavra] para que o tradutor
  /// retorne exatamente a acepção gramatical e semântica usada naquele verso específico.
  Future<({String? wordTranslation, String? lineTranslation, String? lineTranslationWithBlank})>
      fetchContextualWordTranslation({
    required String sentence,
    required String targetWord,
    String sourceLang = 'auto',
    String? targetLang,
  }) async {
    final tl = targetLang ?? await LanguageService().getTargetLanguage();

    try {
      final regex = RegExp(
        r'\b' + RegExp.escape(targetWord) + r'\b',
        caseSensitive: false,
      );
      final sentenceWithMarker = sentence.replaceFirst(regex, '[$targetWord]');

      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$tl&dt=t&q=${Uri.encodeComponent(sentenceWithMarker)}',
      );
      final res = await _client.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final parts = decoded[0] as List;
          final translatedFull = parts
              .map((p) => (p is List && p.isNotEmpty) ? p[0].toString() : '')
              .join('');

          // Extrai o conteúdo dentro de [ ... ]
          final bracketMatch = RegExp(r'\[(.*?)\]').firstMatch(translatedFull);
          String? contextualWord;
          if (bracketMatch != null) {
            contextualWord = bracketMatch.group(1)?.trim();
          }

          // Linha traduzida limpa (removendo colchetes)
          final cleanTranslatedLine = translatedFull
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();

          // Linha traduzida com lacuna substituindo a palavra contextual traduzida
          String? lineWithBlank;
          if (contextualWord != null && contextualWord.isNotEmpty) {
            final transRegex = RegExp(
              r'\b' + RegExp.escape(contextualWord) + r'\b',
              caseSensitive: false,
            );
            if (transRegex.hasMatch(cleanTranslatedLine)) {
              lineWithBlank =
                  cleanTranslatedLine.replaceFirst(transRegex, '_______');
            } else {
              lineWithBlank = translatedFull.replaceFirst(
                  RegExp(r'\[.*?\]'), '_______');
            }
          } else {
            lineWithBlank = cleanTranslatedLine;
          }

          if (contextualWord != null && contextualWord.isNotEmpty) {
            return (
              wordTranslation: contextualWord.toLowerCase(),
              lineTranslation: cleanTranslatedLine,
              lineTranslationWithBlank: lineWithBlank,
            );
          }

          return (
            wordTranslation: null,
            lineTranslation: cleanTranslatedLine,
            lineTranslationWithBlank: cleanTranslatedLine,
          );
        }
      }
    } catch (_) {}

    // Fallback caso falhe a chamada contextual: tradução simples da palavra isolada
    try {
      final transData = await fetchTranslationData(targetWord, targetLang: tl);
      return (
        wordTranslation: transData?.primaryTranslation,
        lineTranslation: null,
        lineTranslationWithBlank: null,
      );
    } catch (_) {
      return (
        wordTranslation: null,
        lineTranslation: null,
        lineTranslationWithBlank: null,
      );
    }
  }
}

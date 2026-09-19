import 'dart:convert';

import 'package:http/http.dart' as http;

class WordDefinition {
  final String word;
  final String? phonetic;
  final String? translation;
  final String? sentenceText;
  final String? sentenceTranslation;
  final List<MeaningItem> meanings;

  const WordDefinition({
    required this.word,
    this.phonetic,
    this.translation,
    this.sentenceText,
    this.sentenceTranslation,
    this.meanings = const [],
  });
}

class MeaningItem {
  final String partOfSpeech;
  final String definition;
  final String? example;

  const MeaningItem({
    required this.partOfSpeech,
    required this.definition,
    this.example,
  });
}

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  final http.Client _client = http.Client();
  final Map<String, WordDefinition> _cache = {};
  final Map<String, String> _translationCache = {};

  /// Prefetch da frase em background para resposta instantânea ao toque
  void prefetchSentence(
    String text, {
    String sourceLang = 'auto',
    String targetLang = 'pt',
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    translateText(clean, sourceLang: sourceLang, targetLang: targetLang);
  }

  /// Traduz um texto (palavra ou frase) com latência ultrabaixa
  Future<String?> translateText(
    String text, {
    String sourceLang = 'auto',
    String targetLang = 'pt',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    final cacheKey = '$clean|$sourceLang|$targetLang';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey];
    }

    String? result;

    // 1. Google Translate GTX Endpoint (Ultra rápido: ~50-150ms)
    try {
      final googleUri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(clean)}',
      );
      final response =
          await _client.get(googleUri).timeout(const Duration(milliseconds: 1800));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data.first is List) {
          final parts = data.first as List;
          final translated =
              parts.map((e) => e is List && e.isNotEmpty ? e[0] : '').join();
          if (translated.trim().isNotEmpty) {
            result = translated.trim();
          }
        }
      }
    } catch (_) {}

    // 2. Fallback MyMemory se necessário
    if (result == null) {
      try {
        final sl = sourceLang == 'auto' ? 'en' : sourceLang;
        final myMemoryUri = Uri.parse(
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(clean)}&langpair=$sl|$targetLang',
        );
        final response =
            await _client.get(myMemoryUri).timeout(const Duration(milliseconds: 2000));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final transText = data['responseData']?['translatedText'] as String?;
          if (transText != null && transText.trim().isNotEmpty) {
            result = transText.trim();
          }
        }
      } catch (_) {}
    }

    if (result != null) {
      _translationCache[cacheKey] = result;
    }
    return result;
  }

  /// Busca tradução da palavra e tradução da frase simultaneamente em batch
  Future<WordDefinition?> lookupWord(
    String rawWord, {
    String? sentence,
    String sourceLang = 'en',
    String targetLang = 'pt',
  }) async {
    final word = rawWord
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s'’-]", unicode: true), '')
        .trim()
        .toLowerCase();
    if (word.isEmpty) return null;

    final cleanSentence = sentence?.trim();
    final cacheKey = '$word|${cleanSentence ?? ''}|$sourceLang|$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    String? phonetic;
    String? translation;
    String? sentenceTranslation;
    final List<MeaningItem> meanings = [];

    final hasSentence = cleanSentence != null && cleanSentence.isNotEmpty;

    // Tradução combinada em uma única chamada de alta velocidade
    final translationFuture = () async {
      if (hasSentence) {
        final batchText = '$word\n$cleanSentence';
        final batchResult = await translateText(
          batchText,
          sourceLang: sourceLang,
          targetLang: targetLang,
        );
        if (batchResult != null) {
          final lines = batchResult.split('\n');
          if (lines.isNotEmpty) {
            translation = lines.first.trim();
            if (lines.length > 1) {
              sentenceTranslation = lines.sublist(1).join('\n').trim();
            }
          }
        }
      }

      if (translation == null || translation!.isEmpty) {
        translation = await translateText(
          word,
          sourceLang: sourceLang,
          targetLang: targetLang,
        );
      }
      if (hasSentence &&
          (sentenceTranslation == null || sentenceTranslation!.isEmpty)) {
        sentenceTranslation = await translateText(
          cleanSentence,
          sourceLang: sourceLang,
          targetLang: targetLang,
        );
      }
    }();

    // Dicionário com timeout curto para não atrasar a exibição
    final dictFuture = () async {
      try {
        final dictUri = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/$sourceLang/${Uri.encodeComponent(word)}',
        );
        final dictRes =
            await _client.get(dictUri).timeout(const Duration(milliseconds: 1400));
        if (dictRes.statusCode == 200) {
          final list = jsonDecode(dictRes.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            phonetic = first['phonetic'] as String?;

            final meaningsRaw = first['meanings'] as List<dynamic>? ?? [];
            for (final m in meaningsRaw) {
              final part = m['partOfSpeech'] as String? ?? '';
              final defs = m['definitions'] as List<dynamic>? ?? [];
              for (final d in defs.take(2)) {
                final defText = d['definition'] as String? ?? '';
                final exampleText = d['example'] as String?;
                if (defText.isNotEmpty) {
                  meanings.add(
                    MeaningItem(
                      partOfSpeech: part,
                      definition: defText,
                      example: exampleText,
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (_) {}
    }();

    await Future.wait([translationFuture, dictFuture]);

    final result = WordDefinition(
      word: word,
      phonetic: phonetic,
      translation: translation,
      sentenceText: cleanSentence,
      sentenceTranslation: sentenceTranslation,
      meanings: meanings,
    );

    if (translation != null ||
        sentenceTranslation != null ||
        meanings.isNotEmpty) {
      _cache[cacheKey] = result;
    }
    return result;
  }
}


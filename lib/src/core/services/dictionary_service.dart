import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WordDefinition {
  final String word;
  final String? phonetic;
  final String? translation;
  final List<MeaningItem> meanings;

  const WordDefinition({
    required this.word,
    this.phonetic,
    this.translation,
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

  final Map<String, WordDefinition> _cache = {};

  /// Busca o significado e tradução da palavra
  Future<WordDefinition?> lookupWord(
    String rawWord, {
    String sourceLang = 'en',
    String targetLang = 'pt',
  }) async {
    final word = rawWord
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s'’-]", unicode: true), '')
        .trim()
        .toLowerCase();
    if (word.isEmpty) return null;

    final cacheKey = '$word|$sourceLang|$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    String? phonetic;
    String? translation;
    final List<MeaningItem> meanings = [];

    // 1. Busca tradução via MyMemory
    try {
      final transUri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(word)}&langpair=$sourceLang|$targetLang',
      );
      final transRes = await http
          .get(transUri)
          .timeout(const Duration(seconds: 4));
      if (transRes.statusCode == 200) {
        final data = jsonDecode(transRes.body) as Map<String, dynamic>;
        final transText = data['responseData']?['translatedText'] as String?;
        if (transText != null && transText.trim().toLowerCase() != word) {
          translation = transText.trim();
        }
      }
    } catch (e) {
      debugPrint('Translation error for $word: $e');
    }

    // 2. Busca definição e fonética via Free Dictionary API
    try {
      final dictUri = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/$sourceLang/${Uri.encodeComponent(word)}',
      );
      final dictRes = await http
          .get(dictUri)
          .timeout(const Duration(seconds: 5));
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
    } catch (e) {
      debugPrint('Dictionary lookup error for $word: $e');
    }

    final result = WordDefinition(
      word: word,
      phonetic: phonetic,
      translation: translation,
      meanings: meanings,
    );

    if (translation != null || meanings.isNotEmpty) {
      _cache[cacheKey] = result;
    }
    return result;
  }
}

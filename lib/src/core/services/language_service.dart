import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Preferência de idioma do usuário persistida no banco SQLite.
class LanguagePreference {
  final String code; // BCP-47 (ex: "pt", "en", "es", "fr")
  final String name; // Nome exibível (ex: "Português", "English")
  final String flag; // Emoji de bandeira

  const LanguagePreference({
    required this.code,
    required this.name,
    required this.flag,
  });
}

/// Idiomas suportados pelo Droplyric.
const List<LanguagePreference> supportedLanguages = [
  LanguagePreference(code: 'pt', name: 'Português', flag: '🇧🇷'),
  LanguagePreference(code: 'en', name: 'English', flag: '🇺🇸'),
  LanguagePreference(code: 'es', name: 'Español', flag: '🇪🇸'),
  LanguagePreference(code: 'fr', name: 'Français', flag: '🇫🇷'),
  LanguagePreference(code: 'it', name: 'Italiano', flag: '🇮🇹'),
  LanguagePreference(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
  LanguagePreference(code: 'ja', name: '日本語', flag: '🇯🇵'),
  LanguagePreference(code: 'ko', name: '한국어', flag: '🇰🇷'),
];

bool isLikelyEnglishWord(String value) {
  final word = value.trim().toLowerCase();
  if (!RegExp(r"^[a-z]+(?:['’][a-z]+)*$").hasMatch(word)) return false;
  const commonForeignWords = {
    'al',
    'dar',
    'la',
    'las',
    'los',
    'por',
    'una',
    'uno',
    'el',
    'que',
    'con',
    'del',
    'para',
    'pero',
    'como',
    'muy',
    'dia',
    'vida',
    'amor',
  };
  if (commonForeignWords.contains(word)) return false;
  if (RegExp(r'(ita|ito|cion|ciones|ando|iendo)$').hasMatch(word)) {
    return false;
  }
  return true;
}

String? detectLyricLanguage(String text) {
  final words = RegExp(
    r"[A-Za-zÀ-ÿ]+",
    unicode: true,
  ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();
  if (words.isEmpty) return null;

  const markers = <String, Set<String>>{
    'es': {
      'el',
      'la',
      'los',
      'las',
      'que',
      'por',
      'para',
      'con',
      'una',
      'uno',
      'del',
      'como',
      'pero',
      'vida',
      'amor',
      'quiero',
      'tengo',
      'eres',
    },
    'pt': {
      'o',
      'a',
      'os',
      'as',
      'que',
      'por',
      'para',
      'com',
      'uma',
      'um',
      'não',
      'do',
      'da',
      'como',
      'você',
      'vida',
      'amor',
    },
    'fr': {
      'le',
      'la',
      'les',
      'des',
      'que',
      'pour',
      'avec',
      'une',
      'un',
      'dans',
      'pas',
      'mon',
      'amour',
      'vie',
    },
    'it': {
      'il',
      'lo',
      'la',
      'gli',
      'che',
      'per',
      'con',
      'una',
      'un',
      'della',
      'non',
      'amore',
      'vita',
    },
    'de': {
      'der',
      'die',
      'das',
      'und',
      'für',
      'mit',
      'ein',
      'eine',
      'nicht',
      'ich',
      'liebe',
      'leben',
    },
  };
  final scores = <String, int>{for (final code in markers.keys) code: 0};
  for (final word in words) {
    for (final entry in markers.entries) {
      if (entry.value.contains(word)) {
        scores[entry.key] = scores[entry.key]! + 1;
      }
    }
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.first.value < 2) return null;
  return ranked.first.key;
}

/// Serviço de gerenciamento de preferências de idioma, persistidas no SQLite.
class LanguageService {
  final AppDatabase _appDatabase;

  static const _keyNativeLanguage = 'native_language';
  static const _keyTargetLanguage = 'target_language';
  static const _keyAppLanguage = 'app_language';

  LanguageService({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase();

  /// Retorna a preferência de idioma nativo do usuário (padrão: Português).
  Future<String> getNativeLanguage() async {
    return await _getPreference(_keyNativeLanguage, defaultValue: 'pt');
  }

  /// Retorna a preferência de idioma alvo/de estudo (padrão: Inglês).
  Future<String> getTargetLanguage() async {
    return await _getPreference(_keyTargetLanguage, defaultValue: 'en');
  }

  /// Salva o idioma nativo do usuário.
  Future<void> setNativeLanguage(String languageCode) async {
    await _setPreference(_keyNativeLanguage, languageCode);
  }

  /// Salva o idioma alvo/de estudo.
  Future<void> setTargetLanguage(String languageCode) async {
    await _setPreference(_keyTargetLanguage, languageCode);
  }

  Future<String> getAppLanguage() async {
    return _getPreference(_keyAppLanguage, defaultValue: 'en');
  }

  Future<void> setAppLanguage(String languageCode) async {
    await _setPreference(_keyAppLanguage, languageCode);
  }

  /// Retorna o LanguagePreference correspondente a um código BCP-47.
  LanguagePreference? findByCode(String code) {
    try {
      return supportedLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }

  Future<String> _getPreference(
    String key, {
    required String defaultValue,
  }) async {
    final db = await _appDatabase.database;
    final result = await db.query(
      AppDatabase.tablePreferences,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return defaultValue;
    return result.first['value'] as String;
  }

  Future<void> _setPreference(String key, String value) async {
    final db = await _appDatabase.database;
    await db.insert(AppDatabase.tablePreferences, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class AppLanguage extends ChangeNotifier {
  static final instance = AppLanguage._();
  AppLanguage._();

  String code = 'en';
  bool loaded = false;

  Future<void> load() async {
    code = await LanguageService().getAppLanguage();
    loaded = true;
    notifyListeners();
  }

  Future<void> set(String next) async {
    await LanguageService().setAppLanguage(next);
    code = next;
    notifyListeners();
  }

  bool get isPortuguese => code == 'pt';
}

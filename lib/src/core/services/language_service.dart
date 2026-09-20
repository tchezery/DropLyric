import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Preferência de idioma do usuário persistida no banco SQLite.
class LanguagePreference {
  final String code; // BCP-47 (ex: "pt", "en", "es", "fr")
  final String name; // Nome exibível (ex: "Português", "English")
  final String flagCode; // Código ISO do país da bandeira

  const LanguagePreference({
    required this.code,
    required this.name,
    required this.flagCode,
  });
}

/// Idiomas suportados pelo Droplyric.
const List<LanguagePreference> supportedLanguages = [
  LanguagePreference(code: 'pt', name: 'Português', flagCode: 'br'),
  LanguagePreference(code: 'en', name: 'English', flagCode: 'us'),
  LanguagePreference(code: 'es', name: 'Español', flagCode: 'es'),
  LanguagePreference(code: 'fr', name: 'Français', flagCode: 'fr'),
  LanguagePreference(code: 'it', name: 'Italiano', flagCode: 'it'),
  LanguagePreference(code: 'de', name: 'Deutsch', flagCode: 'de'),
  LanguagePreference(code: 'ja', name: '日本語', flagCode: 'jp'),
  LanguagePreference(code: 'ko', name: '한국어', flagCode: 'kr'),
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
  ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toSet();
  if (words.isEmpty) return null;

  // Count distinct markers so a repeated refrain cannot dominate detection.
  // Ambiguous English/Portuguese words (a/as/do) are not Portuguese evidence.
  const markers = <String, Set<String>>{
    'en': {
      'i',
      'you',
      'your',
      'yours',
      'the',
      'and',
      'my',
      'mine',
      'we',
      'our',
      'they',
      'their',
      'them',
      'it',
      'its',
      'is',
      'are',
      'was',
      'were',
      'this',
      'that',
      'these',
      'those',
      'with',
      'without',
      'from',
      'for',
      'to',
      'of',
      'in',
      'on',
      'not',
      'have',
      'has',
      'had',
      'will',
      'would',
      'can',
      'could',
      'should',
      'when',
      'where',
      'what',
      'why',
      'who',
      'how',
      'there',
      'here',
      'never',
      'always',
      'love',
      'heart',
      'night',
      'dream',
      'dreams',
      'feel',
      'want',
      'know',
      'let',
      'don',
      'doesn',
      'didn',
      'won',
      'ain',
    },
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
      'os',
      'que',
      'por',
      'para',
      'com',
      'uma',
      'um',
      'não',
      'da',
      'como',
      'você',
      'eu',
      'meu',
      'minha',
      'voces',
      'vocês',
      'saudade',
      'coração',
      'estou',
      'quero',
      'tenho',
      'sou',
      'nosso',
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
  if (ranked.first.value < 2 || ranked.first.value == ranked[1].value) {
    return null;
  }
  return ranked.first.key;
}

/// Serviço de gerenciamento de preferências de idioma, persistidas no SQLite.
class LanguageService {
  final AppDatabase _appDatabase;

  static const _keyNativeLanguage = 'native_language';
  static const _keyTargetLanguage = 'target_language';
  static const _keyAppLanguage = 'app_language';
  static const _keyThemeMode = 'theme_light';

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

  Future<bool> hasAppLanguage() async {
    final db = await _appDatabase.database;
    final result = await db.query(
      AppDatabase.tablePreferences,
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [_keyAppLanguage],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> setAppLanguage(String languageCode) async {
    await _setPreference(_keyAppLanguage, languageCode);
  }

  Future<bool> getThemeMode() async {
    return (await _getPreference(_keyThemeMode, defaultValue: 'light')) ==
        'light';
  }

  Future<void> setThemeMode(bool isLight) async {
    await _setPreference(_keyThemeMode, isLight ? 'light' : 'dark');
  }

  static const _keyOnboardingComplete = 'onboarding_complete';

  Future<bool> isOnboardingComplete() async {
    return (await _getPreference(_keyOnboardingComplete, defaultValue: 'false')) ==
        'true';
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _setPreference(_keyOnboardingComplete, value ? 'true' : 'false');
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

class AppThemeMode extends ChangeNotifier {
  static final instance = AppThemeMode._();
  AppThemeMode._();

  bool isLight = true;
  bool loaded = false;

  Future<void> load() async {
    isLight = await LanguageService().getThemeMode();
    loaded = true;
    notifyListeners();
  }

  Future<void> setLight(bool value) async {
    await LanguageService().setThemeMode(value);
    isLight = value;
    notifyListeners();
  }
}

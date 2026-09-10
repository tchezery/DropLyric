import 'package:sqflite/sqflite.dart';

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

/// Serviço de gerenciamento de preferências de idioma, persistidas no SQLite.
class LanguageService {
  final AppDatabase _appDatabase;

  static const _keyNativeLanguage = 'native_language';
  static const _keyTargetLanguage = 'target_language';

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

  /// Retorna o LanguagePreference correspondente a um código BCP-47.
  LanguagePreference? findByCode(String code) {
    try {
      return supportedLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }

  Future<String> _getPreference(String key, {required String defaultValue}) async {
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
    await db.insert(
      AppDatabase.tablePreferences,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

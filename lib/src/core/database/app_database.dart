import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite_native;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Gerenciamento central do banco de dados SQLite do app.
///
/// - **Mobile** (iOS/Android): usa `sqflite` nativo.
/// - **Web**: usa `sqflite_common_ffi_web` (IndexedDB).
/// - **Desktop** (macOS/Linux/Windows): usa `sqflite_common_ffi`.
class AppDatabase {
  static const _dbName = 'droplyric.db';
  static const _dbVersion = 1;

  // Nomes de tabelas (centralizados para evitar typos)
  static const tableKnownWords = 'known_words';
  static const tablePreferences = 'user_preferences';
  static const tableHistory = 'history_tracks';

  /// Instância singleton
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  sqflite_native.Database? _db;

  /// Retorna o banco de dados, inicializando se necessário.
  Future<sqflite_native.Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<sqflite_native.Database> _initDatabase() async {
    if (kIsWeb) {
      // Web: IndexedDB via sqflite_common_ffi_web
      databaseFactory = databaseFactoryFfiWeb;
      return databaseFactory.openDatabase(
        _dbName,
        options: sqflite_native.OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    // Desktop (macOS, Linux, Windows)
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, _dbName);
      return databaseFactory.openDatabase(
        path,
        options: sqflite_native.OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    // Mobile (iOS / Android): sqflite nativo
    final directory = await sqflite_native.getDatabasesPath();
    final path = join(directory, _dbName);
    return sqflite_native.openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sqflite_native.Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableKnownWords (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        word          TEXT    NOT NULL,
        normalized_word TEXT  NOT NULL,
        language      TEXT    NOT NULL,
        track_name    TEXT,
        created_at    INTEGER NOT NULL,
        UNIQUE(normalized_word, language)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_known_words_language
      ON $tableKnownWords(language)
    ''');

    await db.execute('''
      CREATE TABLE $tablePreferences (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHistory (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id     TEXT    NOT NULL,
        title        TEXT    NOT NULL,
        artist       TEXT    NOT NULL,
        album_art    TEXT,
        preview_url  TEXT,
        spotify_url  TEXT,
        played_at    INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(
    sqflite_native.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migrações futuras serão adicionadas aqui
  }

  /// Fecha a conexão com o banco de dados.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

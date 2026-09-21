import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'src/core/database/app_database.dart';
import 'src/core/services/language_service.dart';
import 'src/core/services/supabase_config.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inicializa o banco de dados SQLite antes de rodar o app.
  // O try/catch garante que um erro de DB não impeça o app de iniciar.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
    );
    await AppDatabase().database;
    await AppLanguage.instance.load();
    await TranslationLanguage.instance.load();
    await AppThemeMode.instance.load();
    await FluentLanguages.instance.load();
  } catch (e) {
    debugPrint('App init error (non-fatal): $e');
  }

  runApp(const MyApp());
}

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'src/core/database/app_database.dart';
import 'src/core/services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o banco de dados SQLite antes de rodar o app.
  // O try/catch garante que um erro de DB não impeça o app de iniciar.
  try {
    await AppDatabase().database;
    await AppLanguage.instance.load();
    await AppThemeMode.instance.load();
    await FluentLanguages.instance.load();
  } catch (e) {
    debugPrint('AppDatabase init error (non-fatal): $e');
  }

  runApp(const MyApp());
}

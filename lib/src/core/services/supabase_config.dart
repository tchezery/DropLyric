import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuração central do Supabase carregada a partir do arquivo .env.
class SupabaseConfig {
  /// URL do projeto Supabase (ex: https://xyzxyz.supabase.co)
  static String get url => dotenv.get('SUPABASE_URL', fallback: '');

  /// Anon / public key do projeto
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  /// Web Client ID do Google OAuth (Google Cloud Console → Credenciais)
  static String get googleWebClientId =>
      dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');

  /// iOS Client ID do Google OAuth (Google Cloud Console → Credenciais)
  static String get googleIosClientId =>
      dotenv.get('GOOGLE_IOS_CLIENT_ID', fallback: '');

  /// Retorna true se as credenciais mínimas do Supabase estiverem configuradas.
  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR_') &&
      !anonKey.contains('YOUR_');
}
/// Configuração central do Supabase.
///
/// ⚠️  PREENCHA antes de rodar:
///   1. Acesse seu projeto em https://supabase.com/dashboard
///   2. Settings → API → cole os valores abaixo
///   3. Para iOS:  adicione GoogleService-Info.plist em ios/Runner/
///   4. Para Android: adicione google-services.json em android/app/
class SupabaseConfig {
  /// URL do projeto Supabase (ex: https://xyzxyz.supabase.co)
  static const String url = 'YOUR_SUPABASE_URL';

  /// Anon / public key do projeto
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Web Client ID do Google OAuth (Google Cloud Console → Credenciais)
  /// Necessário para o Google Sign-In nativo em Android.
  /// No iOS é lido automaticamente do GoogleService-Info.plist.
  static const String googleWebClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID';
}

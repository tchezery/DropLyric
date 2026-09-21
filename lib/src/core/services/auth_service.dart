import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Serviço de autenticação via Google + Supabase.
///
/// É um [ChangeNotifier] — ouça para reagir a mudanças de estado de login.
///
/// Uso:
///   AuthService.instance.signInWithGoogle()
///   AuthService.instance.signOut()
///   AuthService.instance.isSignedIn
///   AuthService.instance.currentUser
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._() {
    // Escuta mudanças de estado de autenticação do Supabase
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
    // Lê o estado atual (ex: sessão restaurada ao abrir o app)
    _user = Supabase.instance.client.auth.currentUser;
  }

  User? _user;

  /// Usuário autenticado atual, ou null se não logado.
  User? get currentUser => _user;

  /// true se o usuário está autenticado.
  bool get isSignedIn => _user != null;

  /// Nome de exibição do usuário (do Google).
  String? get displayName =>
      _user?.userMetadata?['full_name'] as String? ??
      _user?.userMetadata?['name'] as String?;

  /// URL do avatar do Google.
  String? get avatarUrl =>
      _user?.userMetadata?['avatar_url'] as String? ??
      _user?.userMetadata?['picture'] as String?;

  /// Email do usuário.
  String? get email => _user?.email;

  /// Abre o fluxo de login Google nativo e autentica no Supabase.
  /// Retorna true em caso de sucesso.
  Future<bool> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        // No Android, o webClientId é obrigatório para obter o idToken.
        // No iOS, é lido automaticamente do GoogleService-Info.plist.
        clientId: defaultTargetPlatform == TargetPlatform.android
            ? SupabaseConfig.googleWebClientId
            : null,
        serverClientId: SupabaseConfig.googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false; // usuário cancelou

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) return false;

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return true;
    } catch (e) {
      debugPrint('[AuthService] signInWithGoogle error: $e');
      return false;
    }
  }

  /// Desloga do Google e do Supabase.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
  }
}

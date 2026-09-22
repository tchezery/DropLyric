import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'sync_service.dart';

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
    try {
      if (SupabaseConfig.isConfigured) {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final previousUser = _user;
          _user = data.session?.user;
          notifyListeners();
          if (_user != null) {
            SyncService.instance.startRealtime();
            if (previousUser?.id != _user?.id) {
              SyncService.instance.syncAll().ignore();
            }
          } else {
            SyncService.instance.stopRealtime();
          }
        });
        _user = Supabase.instance.client.auth.currentUser;
        if (_user != null) {
          SyncService.instance.startRealtime();
          // A sessão restaurada pode não emitir initialSession depois que este
          // listener foi registrado. Faça uma sincronização explícita para
          // que outro dispositivo não dependa de um novo login.
          SyncService.instance.syncAll().ignore();
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Init error (non-fatal): $e');
    }
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

  String? _lastError;
  String? get lastError => _lastError;

  /// Abre o fluxo de login Google nativo e autentica no Supabase.
  /// Retorna true em caso de sucesso.
  Future<bool> signInWithGoogle() async {
    _lastError = null;
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          kIsWeb) {
        final res = await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'droplyric://callback',
        );
        return res;
      }

      final isApple = defaultTargetPlatform == TargetPlatform.iOS;
      final clientId = isApple
          ? SupabaseConfig.googleIosClientId
          : SupabaseConfig.googleWebClientId;

      final googleSignIn = GoogleSignIn(
        clientId: clientId.isNotEmpty ? clientId : null,
        serverClientId: SupabaseConfig.googleWebClientId.isNotEmpty
            ? SupabaseConfig.googleWebClientId
            : null,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false; // usuário cancelou

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        _lastError = 'Token do Google não obtido.';
        debugPrint('[AuthService] idToken is null (accessToken: ${accessToken != null})');
        return false;
      }

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _user = res.session?.user ?? Supabase.instance.client.auth.currentUser;
      notifyListeners();
      SyncService.instance.syncAll().ignore();

      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[AuthService] signInWithGoogle error: $e');
      return false;
    }
  }

  /// Desloga do Google e do Supabase.
  Future<void> signOut() async {
    SyncService.instance.stopRealtime();

    // 1. Desconecta o Google (limpa cache de credenciais do Google para permitir trocar de conta)
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final isApple = defaultTargetPlatform == TargetPlatform.iOS;
        final clientId = isApple
            ? SupabaseConfig.googleIosClientId
            : SupabaseConfig.googleWebClientId;

        final googleSignIn = GoogleSignIn(
          clientId: clientId.isNotEmpty ? clientId : null,
          serverClientId: SupabaseConfig.googleWebClientId.isNotEmpty
              ? SupabaseConfig.googleWebClientId
              : null,
        );
        try {
          await googleSignIn.disconnect();
        } catch (_) {}
        try {
          await googleSignIn.signOut();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AuthService] Google signOut error: $e');
    }

    // 2. Desloga do Supabase
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Supabase signOut error: $e');
    }

    _user = null;
    notifyListeners();
  }
}

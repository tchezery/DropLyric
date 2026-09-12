import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';

/// Serviço de Autenticação Spotify PKCE Nativo para iOS e Android.
class SpotifyMobileAuth extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = SpotifyMobileAuth._();

  SpotifyMobileAuth._() : _nativeAuthEnabled = false {
    _pendingRestore = _restorePendingLogin();
    if (!_usesNativeAuth) _initAppLinks();
    WidgetsBinding.instance.addObserver(this);
  }

  @visibleForTesting
  SpotifyMobileAuth.forTesting({http.Client? client})
    : _nativeAuthEnabled = true {
    _client = client;
    _pendingRestore = _restorePendingLogin();
  }

  http.Client? _client;
  final bool _nativeAuthEnabled;
  static const _nativeAuth = MethodChannel('droplyric/spotify-auth');
  bool get _usesNativeAuth =>
      _nativeAuthEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool initializing = true;
  bool isConnecting = false;
  int _sessionGeneration = 0;
  bool _disposed = false;
  Future<void> get ready => _pendingRestore;

  static const String clientId = '1bdc621fcaa74a21a2c2f90b5b5f0cbc';
  static const String redirectUri = 'droplyric://callback';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;

  bool get isAuthenticated => accessToken != null && refreshToken != null;
  String? userDisplayName;
  String? userAvatarUrl;
  String error = '';

  String? _pendingVerifier;
  String? _pendingState;
  late final Future<void> _pendingRestore;

  Future<void> _restorePendingLogin() async {
    try {
      if (_usesNativeAuth) {
        _applyNativeSession(
          await _nativeAuth.invokeMapMethod<String, dynamic>('restore'),
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        _pendingVerifier = prefs.getString('spotify_pkce_verifier');
        _pendingState = prefs.getString('spotify_pkce_state');
        accessToken = prefs.getString('spotify_access_token');
        refreshToken = prefs.getString('spotify_refresh_token');
        final expiry = prefs.getInt('spotify_expires_at');
        expiresAt = expiry == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiry);
        if (_isIOS && accessToken != null) {
          try {
            await _nativeAuth.invokeMethod<void>('setAccessToken', accessToken);
          } catch (_) {}
        }
      }
    } catch (_) {
      error = 'Could not restore your Spotify session. Try connecting again.';
    } finally {
      initializing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _applyNativeSession(Map<String, dynamic>? session) {
    accessToken = session?['access_token'] as String?;
    refreshToken = session?['refresh_token'] as String?;
    final expiry = session?['expires_at'] as num?;
    expiresAt = expiry == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expiry.toInt());
    if (session == null) {
      userDisplayName = null;
      userAvatarUrl = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _usesNativeAuth) {
      unawaited(resumeSession());
    }
  }

  Future<void> resumeSession() async {
    await ready;
    if (!isAuthenticated || isConnecting || _disposed) return;
    final generation = _sessionGeneration;
    try {
      final session = await _nativeAuth.invokeMapMethod<String, dynamic>(
        'session',
      );
      if (generation != _sessionGeneration || _disposed) return;
      _applyNativeSession(session);
      error = '';
    } catch (_) {
      // Background disconnection/network failure is not an account logout.
      if (generation != _sessionGeneration || _disposed) return;
      error = 'Could not refresh the session. Check your connection.';
    }
    notifyListeners();
  }

  Future<void> preparePlayback() async {
    await ready;
    if (!isAuthenticated) return;
    if (!_usesNativeAuth) {
      if (_isIOS) {
        await _nativeAuth.invokeMethod<void>('setAccessToken', accessToken);
      }
      return;
    }
    final generation = _sessionGeneration;
    final session = await _nativeAuth.invokeMapMethod<String, dynamic>(
      'session',
    );
    if (generation != _sessionGeneration || _disposed) {
      throw StateError('Sessão encerrada.');
    }
    _applyNativeSession(session);
    if (!isAuthenticated) {
      notifyListeners();
      throw StateError('Connect your Spotify account.');
    }
  }

  void _initAppLinks() {
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    if (uri.scheme == 'droplyric' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final err = uri.queryParameters['error'];

      if (err != null) {
        if (_pendingState == null) return;
        error = 'Spotify login was cancelled.';
        isConnecting = false;
        notifyListeners();
        return;
      }

      if (code != null) {
        if (_pendingState == null || state != _pendingState) return;
        _exchangeCodeForToken(code, state);
      }
    }
  }

  String _randomString(int length) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _createCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<void> login() async {
    await _pendingRestore;
    if (_usesNativeAuth) return _loginNative();
    return loginWeb();
  }

  Future<void> loginApp() async {
    await _pendingRestore;
    if (_isIOS) return _loginNative();
    return loginWeb();
  }

  Future<void> _loginNative() async {
    if (isConnecting) return;
    final generation = ++_sessionGeneration;
    isConnecting = true;
    error = '';
    notifyListeners();
    try {
      final session = await _nativeAuth.invokeMapMethod<String, dynamic>(
        'login',
      );
      if (generation != _sessionGeneration || _disposed) return;
      _applyNativeSession(session);
      await _fetchUserProfile();
    } on PlatformException catch (e) {
      if (generation == _sessionGeneration && !_disposed) {
        error = e.message ?? 'Could not connect to Spotify.';
      }
    } finally {
      if (generation == _sessionGeneration && !_disposed) {
        isConnecting = false;
        notifyListeners();
      }
    }
  }

  Future<void> loginWeb() async {
    await _pendingRestore;
    if (isConnecting) return;
    error = '';
    isConnecting = true;
    notifyListeners();
    _pendingVerifier = _randomString(32);
    _pendingState = _randomString(16);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_pkce_verifier', _pendingVerifier!);
    await prefs.setString('spotify_pkce_state', _pendingState!);

    final challenge = _createCodeChallenge(_pendingVerifier!);

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': 'streaming user-read-email user-read-private user-read-playback-state user-modify-playback-state',
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': _pendingState,
    });

    if (await canLaunchUrl(authUri)) {
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      isConnecting = false;
      error = 'Could not open Spotify Web login.';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ready;
    _sessionGeneration++;
    if (_usesNativeAuth) await _nativeAuth.invokeMethod<void>('logout');
    if (!_usesNativeAuth) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('spotify_access_token');
      await prefs.remove('spotify_refresh_token');
      await prefs.remove('spotify_expires_at');
    }
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    userDisplayName = null;
    userAvatarUrl = null;
    isConnecting = false;
    error = '';
    notifyListeners();
  }

  Future<void> _exchangeCodeForToken(String code, String? state) async {
    await _pendingRestore;
    if (_pendingState == null ||
        state != _pendingState ||
        _pendingVerifier == null) {
      error = 'Invalid Spotify login state.';
      isConnecting = false;
      notifyListeners();
      return;
    }

    try {
      final tokenUri = Uri.https('accounts.spotify.com', '/api/token');
      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': _pendingVerifier ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        accessToken = data['access_token'] as String?;
        refreshToken = data['refresh_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('spotify_access_token', accessToken!);
        await prefs.setString('spotify_refresh_token', refreshToken!);
        await prefs.setInt(
          'spotify_expires_at',
          expiresAt!.millisecondsSinceEpoch,
        );
        if (_isIOS) {
          try {
            await _nativeAuth.invokeMethod<void>('setAccessToken', accessToken);
          } catch (_) {}
        }

        await _fetchUserProfile();
        await prefs.remove('spotify_pkce_verifier');
        await prefs.remove('spotify_pkce_state');
        _pendingVerifier = null;
        _pendingState = null;
        error = '';
        isConnecting = false;
        notifyListeners();
      } else {
        error = 'Spotify authentication failed (${response.statusCode}).';
        isConnecting = false;
        notifyListeners();
      }
    } catch (e) {
      error = 'Spotify connection failed: $e';
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserProfile() async {
    if (accessToken == null) return;
    try {
      final uri = Uri.https('api.spotify.com', '/v1/me');
      final response = await (_client?.get ?? http.get)(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        userDisplayName = data['display_name'] as String?;
        final images = data['images'] as List?;
        if (images != null && images.isNotEmpty) {
          userAvatarUrl = images.first['url'] as String?;
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getTrack(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(id)) {
      throw ArgumentError('Faixa Spotify inválida.');
    }
    return _getJson('/v1/tracks/$id');
  }

  Future<void>? _refreshing;
  Future<void> _ensureToken() async {
    await ready;
    if (accessToken != null &&
        expiresAt != null &&
        expiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return;
    }
    if (refreshToken == null) throw StateError('Connect your Spotify account.');
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    await _refreshing;
  }

  Future<void> _refresh() async {
    if (_usesNativeAuth) {
      final generation = _sessionGeneration;
      final session = await _nativeAuth.invokeMapMethod<String, dynamic>(
        'refresh',
      );
      if (generation != _sessionGeneration || _disposed) {
        throw StateError('Sessão encerrada.');
      }
      _applyNativeSession(session);
      notifyListeners();
      if (!isAuthenticated) throw StateError('Connect your Spotify account.');
      return;
    }
    final response = await http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken!,
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Could not refresh Spotify session (${response.statusCode}).',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    accessToken = data['access_token'] as String;
    refreshToken = data['refresh_token'] as String? ?? refreshToken;
    expiresAt = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num).toInt()),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    await _ensureToken();
    var response = await (_client?.get ?? http.get)(
      Uri.https('api.spotify.com', path, query),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 401) {
      expiresAt = null;
      await _ensureToken();
      response = await (_client?.get ?? http.get)(
        Uri.https('api.spotify.com', path, query),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
    if (response.statusCode != 200) {
      error = 'Spotify error (${response.statusCode}). Try again.';
      notifyListeners();
      throw StateError(error);
    }
    error = '';
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<TrackModel>> searchSpotify(String query) async {
    final data = await _getJson('/v1/search', {
      'q': query,
      'type': 'track',
      'limit': '10',
    });
    final items = data['tracks']?['items'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      final album = item['album'] as Map<String, dynamic>? ?? {};
      final images = album['images'] as List? ?? [];
      final uriStr = item['uri'] as String;
      return TrackModel(
        id: uriStr,
        title: item['name'] as String,
        artist: (item['artists'] as List).map((a) => a['name']).join(', '),
        album: album['name'] as String? ?? '',
        albumArtUrl: images.isEmpty ? null : images.first['url'] as String?,
        previewAudioUrl: uriStr,
        spotifyUrl: item['external_urls']?['spotify'] as String?,
        duration: (item['duration_ms'] as num?)?.toDouble() != null
            ? (item['duration_ms'] as num).toDouble() / 1000
            : null,
        language: '',
      );
    }).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }
}

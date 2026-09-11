import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/track_model.dart';

/// Serviço de Autenticação Spotify PKCE Nativo para iOS e Android.
class SpotifyMobileAuth extends ChangeNotifier {
  static final instance = SpotifyMobileAuth._();

  SpotifyMobileAuth._() {
    _initAppLinks();
  }

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
        error = 'Login Spotify cancelado.';
        notifyListeners();
        return;
      }

      if (code != null) {
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
    error = '';
    _pendingVerifier = _randomString(32);
    _pendingState = _randomString(16);

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
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    userDisplayName = null;
    userAvatarUrl = null;
    notifyListeners();
  }

  Future<void> _exchangeCodeForToken(String code, String? state) async {
    if (_pendingState == null ||
        state != _pendingState ||
        _pendingVerifier == null) {
      error = 'Estado de login inválido.';
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

        await _fetchUserProfile();
        error = '';
        notifyListeners();
      } else {
        error = 'Erro na autenticação do Spotify (${response.statusCode})';
        notifyListeners();
      }
    } catch (e) {
      error = 'Falha de conexão com o Spotify: $e';
      notifyListeners();
    }
  }

  Future<void> _fetchUserProfile() async {
    if (accessToken == null) return;
    try {
      final uri = Uri.https('api.spotify.com', '/v1/me');
      final response = await http.get(
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
    if (accessToken != null &&
        expiresAt != null &&
        expiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return;
    }
    if (refreshToken == null) throw StateError('Conecte sua conta Spotify.');
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    await _refreshing;
  }

  Future<void> _refresh() async {
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
        'Falha ao renovar sessão Spotify (${response.statusCode}).',
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
    var response = await http.get(
      Uri.https('api.spotify.com', path, query),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 401) {
      expiresAt = null;
      await _ensureToken();
      response = await http.get(
        Uri.https('api.spotify.com', path, query),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
    if (response.statusCode != 200) {
      error = 'Erro Spotify (${response.statusCode}). Tente novamente.';
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
      );
    }).toList();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}

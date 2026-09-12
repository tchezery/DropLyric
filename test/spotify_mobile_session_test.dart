import 'dart:async';

import 'package:droplyric/src/core/services/spotify_mobile_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('droplyric/spotify-auth');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, dynamic>? saved;
  late List<String> calls;
  late SpotifyMobileAuth auth;

  Map<String, dynamic> session({bool expired = false, String token = 'access'}) => {
    'access_token': token,
    'refresh_token': 'refresh',
    'expires_at': DateTime.now().add(Duration(hours: expired ? -1 : 1)).millisecondsSinceEpoch,
  };

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    saved = session();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'restore':
        case 'session': return saved;
        case 'login': saved = session(); return saved;
        case 'refresh': saved = session(token: 'renewed'); return saved;
        case 'logout': saved = null; return null;
      }
      throw StateError('Unexpected native call');
    });
  });
  tearDown(() {
    auth.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('app restart restores the saved session without starting login', () async {
    auth = SpotifyMobileAuth.forTesting();
    expect(auth.initializing, isTrue);
    await auth.ready;
    expect(auth.initializing, isFalse);
    expect(auth.isAuthenticated, isTrue);
    auth.dispose();
    auth = SpotifyMobileAuth.forTesting();
    await auth.ready;
    expect(auth.isAuthenticated, isTrue);
    expect(calls, ['restore', 'restore']);
  });

  test('login goes through native Spotify and logout clears the saved session', () async {
    saved = null;
    auth = SpotifyMobileAuth.forTesting(client: MockClient((_) async =>
      http.Response('{"display_name":"Listener","images":[]}', 200)));
    await auth.ready;
    await auth.login();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.userDisplayName, 'Listener');
    expect(calls, ['restore', 'login']);
    await auth.logout();
    expect(saved, isNull);
    expect(auth.isAuthenticated, isFalse);
    auth.dispose();
    auth = SpotifyMobileAuth.forTesting();
    await auth.ready;
    expect(auth.isAuthenticated, isFalse);
  });

  test('expired token renews silently before a catalog request', () async {
    saved = session(expired: true);
    auth = SpotifyMobileAuth.forTesting(client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer renewed');
      return http.Response('{"name":"Track"}', 200);
    }));
    await auth.ready;
    expect(auth.isAuthenticated, isTrue);
    await auth.getTrack('7qiZfU4dY1lWllzX7mPBI3');
    expect(calls, ['restore', 'refresh']);
    expect(auth.accessToken, 'renewed');
  });

  test('returning from another app refreshes state without login', () async {
    auth = SpotifyMobileAuth.forTesting();
    await auth.ready;
    saved = session(token: 'new-access');
    await auth.resumeSession();
    expect(auth.accessToken, 'new-access');
    expect(calls, ['restore', 'session']);
  });

  test('temporary reconnect failure does not log the user out', () async {
    auth = SpotifyMobileAuth.forTesting();
    await auth.ready;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'network');
    });
    await auth.resumeSession();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.refreshToken, 'refresh');
    expect(saved, isNotNull);
  });

  test('a late resume response cannot restore a logged-out account', () async {
    auth = SpotifyMobileAuth.forTesting();
    await auth.ready;
    final response = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'session') {
        started.complete();
        return response.future;
      }
      if (call.method == 'logout') { saved = null; return null; }
      return saved;
    });
    final resume = auth.resumeSession();
    await started.future;
    await auth.logout();
    response.complete(session());
    await resume;
    expect(auth.isAuthenticated, isFalse);
    expect(auth.accessToken, isNull);
  });
}

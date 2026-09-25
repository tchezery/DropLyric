import 'dart:convert';

import 'package:droplyric/src/core/services/auth_service.dart';
import 'package:droplyric/src/core/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restored login initializes auth once and starts realtime', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
      fileInput: '''
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=test-key
''',
    );
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() async {
      SyncService.instance.stopRealtime();
      await Supabase.instance.dispose();
      debugPrint = originalDebugPrint;
      dotenv.clean();
    });
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-key', // ignore: deprecated_member_use
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    // Reopening the app restores a session before AuthService is first read.
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'restored-user',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );

    final auth = AuthService.instance;
    expect(identical(auth, AuthService.instance), isTrue);
    expect(auth.isSignedIn, isTrue);
    expect(auth.currentUser?.id, 'restored-user');
    expect(Supabase.instance.client.getChannels(), hasLength(2));
    final channels = Supabase.instance.client.getChannels().toList();
    SyncService.instance.startRealtime();
    expect(Supabase.instance.client.getChannels(), orderedEquals(channels));
    expect(
      messages.where(
        (message) =>
            message.contains('Stack Overflow') ||
            message.contains('LateInitializationError') ||
            message.contains('Init error'),
      ),
      isEmpty,
    );
  });
}

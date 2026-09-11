import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/services/spotify_bridge_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/messages'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('droplyric/spotify/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('droplyric/spotify'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'play, pause and seek reach native Spotify without preview audio',
    () async {
      const uri = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3';
      await spotifyCall('play', uri);
      await spotifyCall('pause');
      await spotifyCall('seek', '45000');
      expect(calls.map((c) => c.method), ['play', 'pause', 'seek']);
      expect(calls.first.arguments, uri);
      expect(calls.last.arguments, '45000');
    },
  );
  test('invalid track is rejected before native playback', () async {
    await expectLater(
      spotifyCall('play', 'https://example.com/preview.mp3'),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
  test('native failure remains visible to Flutter', () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('droplyric/spotify'),
      (_) async {
        throw PlatformException(
          code: 'spotify_connection',
          message: 'Instale o Spotify.',
        );
      },
    );
    await expectLater(
      spotifyCall('play', 'spotify:track:7qiZfU4dY1lWllzX7mPBI3'),
      throwsA(isA<PlatformException>()),
    );
    expect(jsonDecode(spotifyState())['error'], 'Instale o Spotify.');
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droplyric/src/core/services/spotify_bridge_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
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
    'mobile connection and content use App Remote without a Web session',
    () async {
      messenger.setMockMethodCallHandler(
        const MethodChannel('droplyric/spotify-auth'),
        (_) async {
          fail('Remote-only mode must not request the legacy Web API session');
        },
      );
      await spotifyCall('loginApp');
      expect(calls.single.method, 'connect');
      messenger.setMockMethodCallHandler(
        const MethodChannel('droplyric/spotify'),
        (call) async {
          calls.add(call);
          return [
            {
              'id': 'recommendation',
              'title': 'Mix',
              'uri': 'spotify:playlist:example',
              'playable': true,
              'children': false,
            },
          ];
        },
      );
      final content = jsonDecode(await spotifyCall('content')) as List;
      expect(content.single['title'], 'Mix');
      await spotifyCall('playContent', 'recommendation');
      expect(calls.last.method, 'playContent');
      expect(calls.last.arguments, 'recommendation');
    },
  );
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
  test(
    'macOS uses the native bridge without mobile or Web authentication',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(spotifyWebSupported, isTrue);
      await spotifyCall('loginApp');
      await spotifyCall('play', 'spotify:track:7qiZfU4dY1lWllzX7mPBI3');
      await spotifyCall('seek', '12500');
      await spotifyCall('next');
      await spotifyCall('previous');
      await spotifyCall('pause');
      await spotifyCall('logout');
      expect(calls.map((c) => c.method), [
        'connect',
        'play',
        'seek',
        'next',
        'previous',
        'pause',
        'disconnect',
      ]);
    },
  );
  test('invalid track is rejected before native playback', () async {
    await expectLater(
      spotifyCall('play', 'https://example.com/preview.mp3'),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
  test(
    'iOS routes exact playback, pause, seek and logout to App Remote',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const uri = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3';
      await spotifyCall('play', uri);
      await spotifyCall('pause');
      await spotifyCall('seek', '45000');
      await spotifyCall('logout');
      expect(calls.map((c) => c.method), [
        'play',
        'pause',
        'seek',
        'disconnect',
      ]);
      expect(calls.first.arguments, uri);
      expect(calls[2].arguments, '45000');
    },
  );
  test('iOS rejects external audio before calling native playback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await expectLater(
      spotifyCall('play', 'https://example.com/remix.mp3'),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
  test(
    'native playback events preserve track identity and paused position',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await spotifyCall('initialize');
      const uri = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3';
      await messenger.handlePlatformMessage(
        'droplyric/spotify/events',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'ready': true,
          'paused': true,
          'uri': uri,
          'title': 'Song from SDK',
          'artist': 'Artist',
          'album': 'Album',
          'appRemoteAuthorized': true,
          'position': 45000,
          'duration': 263000,
          'error': '',
        }),
        (_) {},
      );
      final state = jsonDecode(spotifyState()) as Map<String, dynamic>;
      expect(state['uri'], uri);
      expect(state['title'], 'Song from SDK');
      expect(state['artist'], 'Artist');
      expect(state['authenticated'], isTrue);
      expect(state['ready'], isTrue);
      expect(state['paused'], isTrue);
      expect(state['position'], 45000);
      expect(state['duration'], 263000);
    },
  );
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

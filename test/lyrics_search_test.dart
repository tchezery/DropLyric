import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:droplyric/src/core/services/lyrics_service.dart';
import 'package:droplyric/src/widgets/lyrics_search_panel.dart';

Map<String, dynamic> record(int id, String title, {String album = 'Album'}) => {
  'id': id,
  'trackName': title,
  'artistName': 'Test artist',
  'albumName': album,
  'duration': 182.5,
  'instrumental': false,
  'plainLyrics': 'A test line',
  'syncedLyrics': '[00:01.50] A test line',
};

void main() {
  test(
    'search encodes queries and preserves exact versions without Spotify IDs',
    () async {
      final service = LyricsService(
        client: MockClient((request) async {
          expect(request.url.host, 'lrclib.net');
          expect(request.url.path, '/api/search');
          expect(request.url.queryParameters['q'], 'Song & Artist');
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            jsonEncode([record(1, 'Song'), record(2, 'Song', album: 'Live')]),
            200,
          );
        }),
      );
      final results = await service.search(' Song & Artist ');
      expect(results, hasLength(2));
      expect(results.first.track.id, 'lrclib:1');
      expect(results.first.track.previewAudioUrl, isNull);
      expect(results.last.track.album, 'Live');
      expect(results.first.track.duration, 182.5);
      expect(results.first.lyrics!.lines.single.timestamp.inMilliseconds, 1500);
    },
  );
  test(
    'empty input avoids requests and failures remain distinct from no results',
    () async {
      final service = LyricsService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      expect(await service.search(' '), isEmpty);
      await expectLater(service.search('Song'), throwsStateError);
    },
  );
  test('instrumental records do not fabricate lyrics', () async {
    final data = record(3, 'Instrumental')
      ..addAll({
        'instrumental': true,
        'plainLyrics': null,
        'syncedLyrics': null,
      });
    final service = LyricsService(
      client: MockClient((_) async => http.Response(jsonEncode([data]), 200)),
    );
    final result = (await service.search('Instrumental')).single;
    expect(result.instrumental, isTrue);
    expect(result.lyrics, isNull);
  });
  testWidgets('new query wins even if the previous response arrives later', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    final service = LyricsService(
      client: MockClient((request) async {
        if (request.url.queryParameters['q'] == 'first') return first.future;
        return http.Response(jsonEncode([record(2, 'New result')]), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LyricsSearchPanel(service: service),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'first');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    first.complete(http.Response(jsonEncode([record(1, 'Old result')]), 200));
    await tester.pumpAndSettle();
    expect(find.text('Old result'), findsNothing);
    await tester.tap(find.text('New result'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droplyric/src/core/services/spotify_session.dart';
import 'package:droplyric/src/widgets/spotify_access_gate.dart';

class TestSession extends ChangeNotifier implements SpotifySession {
  TestSession({required this.remoteOnly});
  @override
  final bool remoteOnly;
  bool _connected = false;
  @override
  bool get connected => _connected;
  @override
  bool get supported => true;
  @override
  bool get initializing => false;
  @override
  bool get connecting => false;
  @override
  bool get appRemoteAuthorized => false;
  @override
  bool get fullyConnected => false;
  @override
  String get error => '';
  void setConnected(bool value) {
    _connected = value;
    notifyListeners();
  }

  @override
  Future<void> command(String action, [String argument = '']) async {
    setConnected(action == 'loginWeb');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('mobile selection stays accessible without Web API login', (
    tester,
  ) async {
    final session = TestSession(remoteOnly: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyAccessGate(
          session: session,
          child: const Scaffold(body: Text('Choose music')),
        ),
      ),
    );
    expect(find.text('Choose music'), findsOneWidget);
    expect(find.text('Continue with Web'), findsNothing);
    session.setConnected(true);
    await tester.pump();
    session.setConnected(false);
    await tester.pump();
    expect(find.text('Choose music'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  testWidgets('web retains its existing login flow', (tester) async {
    final session = TestSession(remoteOnly: false);
    await tester.pumpWidget(
      MaterialApp(
        home: SpotifyAccessGate(
          session: session,
          child: const Scaffold(body: Text('Catalog')),
        ),
      ),
    );
    expect(find.text('Catalog'), findsNothing);
    await tester.tap(find.text('Continue with Web'));
    await tester.pump();
    expect(find.text('Catalog'), findsOneWidget);
    session.setConnected(false);
    await tester.pump();
    expect(find.text('Catalog'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
